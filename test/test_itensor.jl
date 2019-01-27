using ITensors,
      LinearAlgebra, # For tr()
      Combinatorics, # For permutations()
      Test

digits(::Type{T},i,j,k) where {T} = T(i*10^2+j*10+k)

@testset "ITensor, Dense{$T} storage" for T ∈ (Float64,ComplexF64)
  mi,mj,mk,ml,mα = 2,3,4,5,6,7
  i = Index(mi,"i")
  j = Index(mj,"j")
  k = Index(mk,"k")
  l = Index(ml,"l")
  α = Index(mα,"α") 
  @testset "Set and get values with IndexVals" begin
    A = ITensor(T,i,j,k)
    for ii ∈ 1:dim(i), jj ∈ 1:dim(j), kk ∈ 1:dim(k)
      A[k(kk),j(jj),i(ii)] = digits(T,ii,jj,kk)
    end
    for ii ∈ 1:dim(i), jj ∈ 1:dim(j), kk ∈ 1:dim(k)
      @test A[j(jj),k(kk),i(ii)]==digits(T,ii,jj,kk)
    end
  end
  @testset "Test permute(ITensor,Index...)" begin
    A = randomITensor(T,i,k,j)
    permA = permute(A,k,j,i)
    @test k==inds(permA)[1]
    @test j==inds(permA)[2]
    @test i==inds(permA)[3]
    for ii ∈ 1:dim(i), jj ∈ 1:dim(j), kk ∈ 1:dim(k)
      @test A[k(kk),i(ii),j(jj)]==permA[i(ii),j(jj),k(kk)]
    end
  end
  @testset "Set and get values with Ints" begin
    A = ITensor(T,i,j,k)
    A = permute(A,k,i,j)
    for ii ∈ 1:dim(i), jj ∈ 1:dim(j), kk ∈ 1:dim(k)
      A[kk,ii,jj] = digits(T,ii,jj,kk)
    end
    A = permute(A,i,j,k)
    for ii ∈ 1:dim(i), jj ∈ 1:dim(j), kk ∈ 1:dim(k)
      @test A[ii,jj,kk]==digits(T,ii,jj,kk)
    end
  end
  @testset "Test scalar(ITensor)" begin
    x = T(34)
    A = ITensor(x)
    @test x==scalar(A)
  end
  @testset "Test norm(ITensor)" begin
    A = randomITensor(T,i,j,k)
    @test norm(A)≈sqrt(scalar(dag(A)*A))
  end
  @testset "Test add ITensors" begin
    A = randomITensor(T,i,j,k)
    B = randomITensor(T,k,i,j)
    C = A+B
    for ii ∈ 1:dim(i), jj ∈ 1:dim(j), kk ∈ 1:dim(k)
      @test C[i(ii),j(jj),k(kk)]==A[j(jj),i(ii),k(kk)]+B[i(ii),k(kk),j(jj)]
    end
    @test Array(permute(C,i,j,k))==Array(permute(A,i,j,k))+Array(permute(B,i,j,k))
  end

  @testset "Test factorizations of an ITensor" begin
    A = randomITensor(T,i,j,k,l)
    @testset "Test SVD of an ITensor" begin
      U,S,V = svd(A,j,l)
      u = commonindex(U,S)
      v = commonindex(S,V)
      @test A≈U*S*V
      @test U*dag(prime(U,u))≈δ(T,u,prime(u)) atol=1e-14
      @test V*dag(prime(V,v))≈δ(T,v,prime(v)) atol=1e-14
    end
    @testset "Test QR decomposition of an ITensor" begin
      Q,R = qr(A,i,l)
      q = commonindex(Q,R)
      @test A≈Q*R
      @test Q*dag(prime(Q,q))≈δ(T,q,prime(q)) atol=1e-14
    end
    @testset "Test polar decomposition of an ITensor" begin
      U,P = polar(A,k,l)
      u = commonindex(U,P)
      @test A≈U*P
      #Note: this is only satisfied when left dimensions 
      #are greater than right dimensions
      @test U*dag(prime(U,u))≈δ(T,u,prime(u)) atol=1e-14
    end
  end # End ITensor factorization testset
end # End Dense storage test
