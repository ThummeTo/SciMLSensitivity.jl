using Random; Random.seed!(1234)
using OrdinaryDiffEq
using Statistics
using ForwardDiff, Calculus
using DiffEqSensitivity
using Test
using Zygote

@testset "LSS" begin
  @testset "Lorentz single parameter" begin
    function lorenz!(du,u,p,t)
      du[1] = 10*(u[2]-u[1])
      du[2] = u[1]*(p[1]-u[3]) - u[2]
      du[3] = u[1]*u[2] - (8//3)*u[3]
    end

    p = [28.0]
    tspan_init = (0.0,30.0)
    tspan_attractor = (30.0,50.0)
    u0 = rand(3)
    prob_init = ODEProblem(lorenz!,u0,tspan_init,p)
    sol_init = solve(prob_init,Tsit5())
    prob_attractor = ODEProblem(lorenz!,sol_init[end],tspan_attractor,p)
    sol_attractor = solve(prob_attractor,Vern9(),abstol=1e-14,reltol=1e-14)

    g(u,p,t) = u[end]
    function dg(out,u,p,t,i)
      fill!(out, zero(eltype(u)))
      out[end] = -one(eltype(u))
    end
    lss_problem1 = ForwardLSSProblem(sol_attractor, ForwardLSS(), g)
    lss_problem1a = ForwardLSSProblem(sol_attractor, ForwardLSS(), nothing, dg)
    lss_problem2 = ForwardLSSProblem(sol_attractor, ForwardLSS(alpha=DiffEqSensitivity.Cos2Windowing()), g)
    lss_problem2a = ForwardLSSProblem(sol_attractor, ForwardLSS(alpha=DiffEqSensitivity.Cos2Windowing()), nothing, dg)
    lss_problem3 = ForwardLSSProblem(sol_attractor, ForwardLSS(alpha=10), g)
    lss_problem3a = ForwardLSSProblem(sol_attractor, ForwardLSS(alpha=10), g, dg) #ForwardLSS with time dilation requires knowledge of g

    adjointlss_problem = AdjointLSSProblem(sol_attractor, AdjointLSS(alpha=10.0), g)
    adjointlss_problem_a = AdjointLSSProblem(sol_attractor, AdjointLSS(alpha=10.0), g, dg)

    res1 = DiffEqSensitivity.__solve(lss_problem1)
    res1a = DiffEqSensitivity.__solve(lss_problem1a)
    res2 = DiffEqSensitivity.__solve(lss_problem2)
    res2a = DiffEqSensitivity.__solve(lss_problem2a)
    res3 = DiffEqSensitivity.__solve(lss_problem3)
    res3a = DiffEqSensitivity.__solve(lss_problem3a)

    res4 = DiffEqSensitivity.__solve(adjointlss_problem)
    res4a = DiffEqSensitivity.__solve(adjointlss_problem_a)

    @test res1[1] ≈ 1 atol=5e-2
    @test res2[1] ≈ 1 atol=5e-2
    @test res3[1] ≈ 1 atol=5e-2

    @test res1 ≈ res1a atol=1e-10
    @test res2 ≈ res2a atol=1e-10
    @test res3 ≈ res3a atol=1e-10
    @test res3 ≈ res4 atol=1e-10
    @test res3 ≈ res4a atol=1e-10

    # fixed saveat to compare with concrete solve
    sol_attractor2 = solve(prob_attractor,Vern9(),abstol=1e-14,reltol=1e-14, saveat=0.01)
    lss_problem1 = ForwardLSSProblem(sol_attractor2, ForwardLSS(), g)
    lss_problem1a = ForwardLSSProblem(sol_attractor2, ForwardLSS(), nothing, dg)
    lss_problem2 = ForwardLSSProblem(sol_attractor2, ForwardLSS(alpha=DiffEqSensitivity.Cos2Windowing()), g)
    lss_problem2a = ForwardLSSProblem(sol_attractor2, ForwardLSS(alpha=DiffEqSensitivity.Cos2Windowing()), nothing, dg)
    lss_problem3 = ForwardLSSProblem(sol_attractor2, ForwardLSS(alpha=10), g)
    lss_problem3a = ForwardLSSProblem(sol_attractor2, ForwardLSS(alpha=10), g, dg) #ForwardLSS with time dilation requires knowledge of g

    adjointlss_problem = AdjointLSSProblem(sol_attractor2, AdjointLSS(alpha=10.0), g)
    adjointlss_problem_a = AdjointLSSProblem(sol_attractor2, AdjointLSS(alpha=10.0), g, dg)

    res1 = DiffEqSensitivity.__solve(lss_problem1)
    res1a = DiffEqSensitivity.__solve(lss_problem1a)
    res2 = DiffEqSensitivity.__solve(lss_problem2)
    res2a = DiffEqSensitivity.__solve(lss_problem2a)
    res3 = DiffEqSensitivity.__solve(lss_problem3)
    res3a = DiffEqSensitivity.__solve(lss_problem3a)

    res4 = DiffEqSensitivity.__solve(adjointlss_problem)
    res4a = DiffEqSensitivity.__solve(adjointlss_problem_a)

    @test res1[1] ≈ 1 atol=5e-2
    @test res2[1] ≈ 1 atol=5e-2
    @test res3[1] ≈ 1 atol=5e-2

    @test res1 ≈ res1a atol=1e-10
    @test res2 ≈ res2a atol=1e-10
    @test res3 ≈ res3a atol=1e-10
    @test res3 ≈ res4 atol=1e-10
    @test res3 ≈ res4a atol=1e-10

    function G(p; sensealg=ForwardLSS(), dt=0.01, g=nothing)
      _prob = remake(prob_attractor,p=p)
      _sol = solve(_prob,Vern9(),abstol=1e-14,reltol=1e-14,saveat=dt,sensealg=sensealg, g=g)
      sum(getindex.(_sol.u,3))
    end

    dp1 = Zygote.gradient((p)->G(p),p)
    @test res1 ≈ dp1[1] atol=1e-10

    dp1 = Zygote.gradient((p)->G(p, sensealg=ForwardLSS(alpha=DiffEqSensitivity.Cos2Windowing())),p)
    @test res2 ≈ dp1[1] atol=1e-10

    dp1 = Zygote.gradient((p)->G(p, sensealg=ForwardLSS(alpha=10), g=g),p)
    @test res3 ≈ dp1[1] atol=1e-10

    dp1 = Zygote.gradient((p)->G(p, sensealg=AdjointLSS(alpha=10.0), g=g),p)
    @test res4 ≈ dp1[1] atol=1e-10

    @show res1[1] res2[1] res3[1]
  end

  @testset "Lorentz" begin
    function lorenz!(du,u,p,t)
      du[1] = p[1]*(u[2]-u[1])
      du[2] = u[1]*(p[2]-u[3]) - u[2]
      du[3] = u[1]*u[2] - p[3]*u[3]
    end

    p = [10.0, 28.0, 8/3]

    tspan_init = (0.0,30.0)
    tspan_attractor = (30.0,50.0)
    u0 = rand(3)
    prob_init = ODEProblem(lorenz!,u0,tspan_init,p)
    sol_init = solve(prob_init,Tsit5())
    prob_attractor = ODEProblem(lorenz!,sol_init[end],tspan_attractor,p)
    sol_attractor = solve(prob_attractor,Vern9(),abstol=1e-14,reltol=1e-14)

    g(u,p,t) = u[end] + sum(p)
    function dgu(out,u,p,t,i)
      fill!(out, zero(eltype(u)))
      out[end] = -one(eltype(u))
    end
    function dgp(out,u,p,t,i)
      fill!(out, -one(eltype(p)))
    end

    lss_problem = ForwardLSSProblem(sol_attractor, ForwardLSS(alpha=10), g)
    lss_problem_a = ForwardLSSProblem(sol_attractor, ForwardLSS(alpha=10), g, (dgu,dgp))
    adjointlss_problem = AdjointLSSProblem(sol_attractor, AdjointLSS(alpha=10.0), g)
    adjointlss_problem_a = AdjointLSSProblem(sol_attractor, AdjointLSS(alpha=10.0), g, (dgu,dgp))

    resfw = DiffEqSensitivity.__solve(lss_problem)
    resfw_a = DiffEqSensitivity.__solve(lss_problem_a)
    resadj = DiffEqSensitivity.__solve(adjointlss_problem)
    resadj_a = DiffEqSensitivity.__solve(adjointlss_problem_a)

    @test resfw ≈ resadj rtol=1e-10
    @test resfw ≈ resfw_a rtol=1e-10
    @test resfw ≈ resadj_a rtol=1e-10

    sol_attractor2 = solve(prob_attractor,Vern9(),abstol=1e-14,reltol=1e-14, saveat=0.01)
    lss_problem = ForwardLSSProblem(sol_attractor2, ForwardLSS(alpha=10), g)
    resfw = DiffEqSensitivity.__solve(lss_problem)

    function G(p; sensealg=ForwardLSS(), dt=0.01, g=nothing)
      _prob = remake(prob_attractor,p=p)
      _sol = solve(_prob,Vern9(),abstol=1e-14,reltol=1e-14,saveat=dt,sensealg=sensealg, g=g)
      sum(getindex.(_sol.u,3)) + sum(p)
    end

    dp1 = Zygote.gradient((p)->G(p, sensealg=ForwardLSS(alpha=10), g=g),p)
    @test resfw ≈ dp1[1] atol=1e-10

    dp1 = Zygote.gradient((p)->G(p, sensealg=AdjointLSS(alpha=10.0), g=g),p)
    @test resfw ≈ dp1[1] atol=1e-10

    @show resfw
  end

  @testset "T0skip and T1skip" begin
    function lorenz!(du,u,p,t)
      du[1] = p[1]*(u[2]-u[1])
      du[2] = u[1]*(p[2]-u[3]) - u[2]
      du[3] = u[1]*u[2] - p[3]*u[3]
    end

    p = [10.0, 28.0, 8/3]

    tspan_init = (0.0,30.0)
    tspan_attractor = (30.0,50.0)
    u0 = rand(3)
    prob_init = ODEProblem(lorenz!,u0,tspan_init,p)
    sol_init = solve(prob_init,Tsit5())
    prob_attractor = ODEProblem(lorenz!,sol_init[end],tspan_attractor,p)
    sol_attractor = solve(prob_attractor,Vern9(),abstol=1e-14,reltol=1e-14, saveat=0.01)

    g(u,p,t) = u[end]^2/2 + sum(p)
    function dgu(out,u,p,t,i)
      fill!(out, zero(eltype(u)))
      out[end] = -u[end]
    end
    function dgp(out,u,p,t,i)
      fill!(out, -one(eltype(p)))
    end

    function G(p; sensealg=ForwardLSS(), dt=0.01, g=nothing, t0skip=0.0, t1skip=0.0)
      _prob = remake(prob_attractor,p=p)
      _sol = solve(_prob,Vern9(),abstol=1e-14,reltol=1e-14,saveat=dt,sensealg=sensealg, g=g, t0skip=t0skip, t1skip=t1skip)
      sum(getindex.(_sol.u,3).^2)/2 + sum(p)
    end

    ## ForwardLSS

    lss_problem = ForwardLSSProblem(sol_attractor, ForwardLSS(alpha=10), g)
    resfw = DiffEqSensitivity.__solve(lss_problem)

    res = deepcopy(resfw)

    dp1 = Zygote.gradient((p)->G(p, sensealg=ForwardLSS(alpha=10), g=g),p)
    @test resfw ≈ dp1[1] atol=1e-10

    resfw = DiffEqSensitivity.__solve(lss_problem; t0skip=10.0, t1skip=5.0)

    dp1 = Zygote.gradient((p)->G(p, sensealg=ForwardLSS(alpha=10), g=g, t0skip=10.0, t1skip=5.0),p)
    @test resfw ≈ dp1[1] atol=1e-10

    @show res resfw

    ## ForwardLSS with dgdu and dgdp

    lss_problem2 = ForwardLSSProblem(sol_attractor, ForwardLSS(alpha=10), g, (dgu,dgp))
    res2 = DiffEqSensitivity.__solve(lss_problem2)
    @test res ≈ res2 atol=1e-10
    res2 = DiffEqSensitivity.__solve(lss_problem2; t0skip=10.0, t1skip=5.0)
    @test resfw ≈ res2 atol=1e-10

    ## AdjointLSS

    lss_problem2 = AdjointLSSProblem(sol_attractor, AdjointLSS(alpha=10.0), g)
    res2 = DiffEqSensitivity.__solve(lss_problem2)
    @test res ≈ res2 atol=1e-10
    res2 = DiffEqSensitivity.__solve(lss_problem2; t0skip=10.0, t1skip=5.0)
    @test_broken resfw ≈ res2 atol=1e-10

    dp1 = Zygote.gradient((p)->G(p, sensealg=AdjointLSS(alpha=10.0), g=g),p)
    @test res ≈ dp1[1] atol=1e-10

    dp1 = Zygote.gradient((p)->G(p, sensealg=AdjointLSS(alpha=10), g=g, t0skip=10.0, t1skip=5.0),p)
    @test res2 ≈ dp1[1] atol=1e-10

    ## AdjointLSS with dgdu and dgd

    lss_problem2 = AdjointLSSProblem(sol_attractor, AdjointLSS(alpha=10.0), g, (dgu,dgp))
    res2 = DiffEqSensitivity.__solve(lss_problem2)
    @test res ≈ res2 atol=1e-10
    res2 = DiffEqSensitivity.__solve(lss_problem_2; t0skip=10.0, t1skip=5.0)
    @test_broken resfw ≈ res2 atol=1e-10
  end
end
