export BlockSparseTensor,
       blockview

#
# BlockSparseTensor (Tensor using BlockSparse storage)
#

const BlockSparseTensor{ElT,N,StoreT,IndsT} = Tensor{ElT,N,StoreT,IndsT} where {StoreT<:BlockSparse}

blockoffsets(T::BlockSparseTensor) = blockoffsets(store(T))
nnzblocks(T::BlockSparseTensor) = nnzblocks(store(T))
nnz(T::BlockSparseTensor) = nnz(store(T))

nblocks(T::BlockSparseTensor) = nblocks(inds(T))
blockdims(T::BlockSparseTensor{ElT,N},
          block::Block{N}) where {ElT,N} = blockdims(inds(T),block)
blockdim(T::BlockSparseTensor{ElT,N},
         block::Block{N}) where {ElT,N} = blockdim(inds(T),block)

"""
offset(T::BlockSparseTensor,
       block::Block)

Get the linear offset in the data storage for the specified block.
If the specified block is not non-zero structurally, return nothing.
"""
function offset(T::BlockSparseTensor{ElT,N},
                block::Block{N}) where {ElT,N}
  return offset(blockoffsets(T),block)
end

# Get the offset if the nth block in the block-offsets
# list
offset(T::BlockSparseTensor,n::Int) = offset(blockoffsets(T),n)

"""
blockdim(T::BlockSparseTensor,pos::Int)

Get the block dimension of the block at position pos.
"""
function blockdim(T::BlockSparseTensor,
                  pos::Int)
  if nnzblocks(T)==0
    return 0
  elseif pos==nnzblocks(T)
    return nnz(T)-offset(T,pos)
  end
  return offset(T,pos+1)-offset(T,pos)
end

findblock(T::BlockSparseTensor{ElT,N},
          block::Block{N}) where {ElT,N} = findblock(blockoffsets(T),block)

new_block_pos(T::BlockSparseTensor{ElT,N},
              block::Block{N}) where {ElT,N} = new_block_pos(blockoffsets(T),block)
"""
isblocknz(T::BlockSparseTensor,
          block::Block)

Check if the specified block is non-zero
"""
function isblocknz(T::BlockSparseTensor{ElT,N},
                   block::Block{N}) where {ElT,N}
  isnothing(findblock(T,block)) && return false
  return true
end

function BlockSparseTensor(::Type{ElT},
                           ::UndefInitializer,
                           blockoffsets::BlockOffsets{N},
                           inds) where {ElT<:Number,N}
  nnz_tot = nnz(blockoffsets,inds)
  storage = BlockSparse(ElT,undef,blockoffsets,nnz_tot)
  return Tensor(storage,inds)
end

function BlockSparseTensor(::UndefInitializer,
                           blockoffsets::BlockOffsets{N},
                           inds) where {N}
  return BlockSparseTensor(Float64,undef,blockoffsets,inds)
end

function BlockSparseTensor(::Type{ElT},
                           blockoffsets::BlockOffsets{N},
                           inds) where {ElT<:Number,N}
  nnz_tot = nnz(blockoffsets,inds)
  storage = BlockSparse(ElT,blockoffsets,nnz_tot)
  return Tensor(storage,inds)
end

function BlockSparseTensor(blockoffsets::BlockOffsets{N},
                           inds) where {N}
  return BlockSparseTensor(Float64,blockoffsets,inds)
end

"""
BlockSparseTensor(::UndefInitializer,
                  blocks::Vector{Block{N}},
                  inds)

Construct a block sparse tensor with uninitialized memory
from indices and locations of non-zero blocks.
"""
function BlockSparseTensor(::UndefInitializer,
                           blocks::Vector{Block{N}},
                           inds) where {N}
  blockoffsets,nnz = get_blockoffsets(blocks,inds)
  storage = BlockSparse(undef,blockoffsets,nnz)
  return Tensor(storage,inds)
end

function BlockSparseTensor(::UndefInitializer,
                           blocks::Vector{Block{N}},
                           inds::Vararg{DimT,N}) where {DimT,N}
  return BlockSparseTensor(undef,blocks,inds)
end

"""
BlockSparseTensor(inds)

Construct a block sparse tensor with no blocks.
"""
function BlockSparseTensor(inds)
  return BlockSparseTensor(BlockOffsets{length(inds)}(),inds)
end

"""
BlockSparseTensor(inds)

Construct a block sparse tensor with no blocks.
"""
function BlockSparseTensor(inds::Vararg{DimT,N}) where {DimT,N}
  return BlockSparseTensor(BlockOffsets{N}(),inds)
end

"""
BlockSparseTensor(blocks::Vector{Block{N}},
                  inds)

Construct a block sparse tensor with the specified blocks.
Defaults to setting structurally non-zero blocks to zero.
"""
function BlockSparseTensor(blocks::Vector{Block{N}},
                           inds) where {N}
  blockoffsets,offset_total = get_blockoffsets(blocks,inds)
  storage = BlockSparse(blockoffsets,offset_total)
  return Tensor(storage,inds)
end

"""
BlockSparseTensor(blocks::Vector{Block{N}},
                  inds...)

Construct a block sparse tensor with the specified blocks.
Defaults to setting structurally non-zero blocks to zero.
"""
function BlockSparseTensor(blocks::Vector{Block{N}},
                           inds::Vararg{DimT,N}) where {DimT,N}
  return BlockSparseTensor(blocks,inds)
end

function Base.similar(::BlockSparseTensor{ElT,N},
                      blockoffsets::BlockOffsets{N},
                      inds) where {ElT,N}
  return BlockSparseTensor(ElT,undef,blockoffsets,inds)
end

# Basic functionality for AbstractArray interface
Base.IndexStyle(::Type{<:BlockSparseTensor}) = IndexCartesian()

# Given a CartesianIndex in the range dims(T), get the block it is in
# and the index within that block
function blockindex(T::BlockSparseTensor{ElT,N},
                    i::Vararg{Int,N}) where {ElT,N}
  # Start in the (1,1,...,1) block
  current_block_loc = @MVector ones(Int,N)
  current_block_dims = blockdims(T,Tuple(current_block_loc))
  block_index = MVector(i)
  for dim in 1:N
    while block_index[dim] > current_block_dims[dim]
      block_index[dim] -= current_block_dims[dim]
      current_block_loc[dim] += 1
      current_block_dims = blockdims(T,Tuple(current_block_loc))
    end
  end
  return Block{N}(block_index),Tuple(current_block_loc)
end

# Get the starting index of the block
function blockstart(T::BlockSparseTensor{ElT,N},
                    block::Block{N}) where {ElT,N}
  start_index = @MVector ones(Int,N)
  for j in 1:N
    ind_j = ind(T,j)
    for block_j in 1:block[j]-1
      start_index[j] += blockdim(ind_j,block_j)
    end
  end
  return CartesianIndex(Tuple(start_index))
end

# Get the ending index of the block
function blockend(T::BlockSparseTensor{ElT,N},
                  block) where {ElT,N}
  end_index = @MVector zeros(Int,N)
  for j in 1:N
    ind_j = ind(T,j)
    for block_j in 1:block[j]
      end_index[j] += blockdim(ind_j,block_j)
    end
  end
  return CartesianIndex(Tuple(end_index))
end

# Get the CartesianIndices for the range of indices
# of the specified
function blockindices(T::BlockSparseTensor{ElT,N},
                      block) where {ElT,N}
  return blockstart(T,block):blockend(T,block)
end

"""
indexoffset(T::BlockSparseTensor,i::Int...) -> offset,block,blockoffset

Get the offset in the data of the specified
CartesianIndex. If it falls in a block that doesn't
exist, return nothing for the offset.
Also returns the block the index is found in and the offset
within the block.
"""
function indexoffset(T::BlockSparseTensor{ElT,N},
                     i::Vararg{Int,N}) where {ElT,N}
  index_within_block,block = blockindex(T,i...)
  block_dims = blockdims(T,block)
  offset_within_block = LinearIndices(block_dims)[CartesianIndex(index_within_block)]
  offset_of_block = offset(T,block)
  offset_of_i = isnothing(offset_of_block) ? nothing : offset_of_block+offset_within_block
  return offset_of_i,block,offset_within_block
end

# TODO: Add a checkbounds
# TODO: write this nicer in terms of blockview?
#       Could write: 
#       block,index_within_block = blockindex(T,i...)
#       return blockview(T,block)[index_within_block]
Base.@propagate_inbounds function Base.getindex(T::BlockSparseTensor{ElT,N},
                                                i::Vararg{Int,N}) where {ElT,N}
  offset,_ = indexoffset(T,i...)
  isnothing(offset) && return zero(ElT)
  return store(T)[offset]
end

# These may not be valid if the Tensor has no blocks
#Base.@propagate_inbounds Base.getindex(T::BlockSparseTensor{<:Number,1},ind::Int) = store(T)[ind]

#Base.@propagate_inbounds Base.getindex(T::BlockSparseTensor{<:Number,0}) = store(T)[1]

# Add the specified block to the BlockSparseTensor
# Insert it such that the blocks remain ordered.
# Defaults to adding zeros.
function addblock!(T::BlockSparseTensor{ElT,N},
                   newblock::Block{N}) where {ElT,N}
  newdim = blockdim(T,newblock)
  newpos = new_block_pos(T,newblock)
  newoffset = 0
  if nnzblocks(T)>0
    newoffset = offset(T,newpos-1)+blockdim(T,newpos-1)
  end
  insert!(blockoffsets(T),newpos,BlockOffset{N}(newblock,newoffset))
  splice!(data(store(T)),newoffset+1:newoffset,zeros(ElT,newdim))
  for i in newpos+1:nnzblocks(T)
    block_i,offset_i = blockoffsets(T)[i]
    blockoffsets(T)[i] = BlockOffset{N}(block_i,offset_i+newdim)
  end
  return newoffset
end

# TODO: Add a checkbounds
Base.@propagate_inbounds function Base.setindex!(T::BlockSparseTensor{ElT,N},
                                                 val,
                                                 i::Vararg{Int,N}) where {ElT,N}
  offset,block,offset_within_block = indexoffset(T,i...)
  if isnothing(offset)
    offset_of_block = addblock!(T,block)
    offset = offset_of_block+offset_within_block
  end
  store(T)[offset] = val
  return T
end

# Given a specified block, return a Dense Tensor that is a view to the data
# in that block
function blockview(T::BlockSparseTensor{ElT,N},
                   block) where {ElT,N}
  !isblocknz(T,block) && error("Block must be structurally non-zero to get a view")
  blockoffsetT = offset(T,block)
  blockdimsT = blockdims(T,block)
  dataTslice = @view data(store(T))[blockoffsetT+1:blockoffsetT+prod(blockdimsT)]
  return Tensor(Dense(dataTslice),blockdimsT)
end

# convert to Dense
function dense(T::TensorT) where {TensorT<:BlockSparseTensor}
  R = zeros(dense(TensorT),dense(inds(T)))
  for (block,offset) in blockoffsets(T)
    # TODO: make sure this assignment is efficient
    R[blockindices(T,block)] = blockview(T,block)
  end
  return R
end

#
# Operations
#

# TODO: extend to case with different block structures
function Base.:+(T1::BlockSparseTensor,T2::BlockSparseTensor)
  inds(T1) ≠ inds(T2) && error("Cannot add block sparse tensors with different block structure")  
  return Tensor(store(T1)+store(T2),inds(T1))
end

function Base.permutedims(T::BlockSparseTensor{<:Number,N},
                          perm::NTuple{N,Int}) where {N}
  blockoffsetsR,indsR = permute(blockoffsets(T),inds(T),perm)
  R = similar(T,blockoffsetsR,indsR)
  R = permutedims!!(R,T,perm)
  return R
end

# TODO: handle case with different block structures
function permutedims!!(R::BlockSparseTensor{<:Number,N},
                       T::BlockSparseTensor{<:Number,N},
                       perm::NTuple{N,Int}) where {N}
  R = permutedims!(R,T,perm)
  return R
end

function Base.permutedims!(R::BlockSparseTensor{<:Number,N},
                           T::BlockSparseTensor{<:Number,N},
                           perm::NTuple{N,Int}) where {N}
  for (blockT,_) in blockoffsets(T)
    # Loop over non-zero blocks of T/R
    Tblock = blockview(T,blockT)
    Rblock = blockview(R,permute(blockT,perm))
    permutedims!(Rblock,Tblock,perm)
  end
  return R
end

#
# Contraction
#

# TODO: complete this function: determine the output blocks from the input blocks
# Also, save the contraction list (which block-offsets contract with which),
# may not be generic with other contraction functions!
function contraction_output(T1::TensorT1,
                            T2::TensorT2,
                            indsR::IndsR) where {TensorT1<:BlockSparseTensor,
                                                 TensorT2<:BlockSparseTensor,
                                                 IndsR}
  TensorR = contraction_output_type(TensorT1,TensorT2,IndsR)
  #error("In contraction_output(::BlockSparseTensor,BlockSparseTensor,::IndsR), need to determine output blocks")
  return similar(TensorR,indsR,offsetsR)
end

#
# Print block sparse tensors
#

function Base.summary(io::IO,
                      T::BlockSparseTensor{ElT,N}) where {ElT,N}
  println(io,typeof(T))
  println(io," ",Base.dims2string(dims(T)))
  for (dim,ind) in enumerate(inds(T))
    println(io,"Dim $dim: ",ind)
  end
  println("Number of nonzero blocks: ",nnzblocks(T))
end

function Base.show(io::IO,
                   mime::MIME"text/plain",
                   T::BlockSparseTensor)
  summary(io,T)
  println(io)
  for (block,_) in blockoffsets(T)
    blockdimsT = blockdims(T,block)
    # Print the location of the current block
    println(io,"Block: ",block)
    # Print the dimension of the current block
    println(io," ",Base.dims2string(blockdimsT))
    # TODO: replace with a Tensor show method
    # instead of converting to array (for other
    # storage types, like CuArray)
    Tblock = array(blockview(T,block))
    Base.print_array(io,Tblock)
    println(io)
    println(io)
  end
end

Base.show(io::IO, T::BlockSparseTensor) = show(io,MIME("text/plain"),T)

