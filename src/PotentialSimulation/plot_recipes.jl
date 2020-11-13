function get_crosssection_idx_and_value(g::Grid{T, 3, :cylindrical}, r, φ, z)::Tuple{Symbol,Int,T} where {T <: SSDFloat}

    cross_section::Symbol, idx::Int = if ismissing(φ) && ismissing(r) && ismissing(z)
        :φ, 1
    elseif !ismissing(φ) && ismissing(r) && ismissing(z)
        φ_rad::T = T(deg2rad(φ))
        while !(g.φ.interval.left <= φ_rad <= g.φ.interval.right) && g.φ.interval.right != g.φ.interval.left
            if φ_rad > g.φ.interval.right
                φ_rad -= g.φ.interval.right - g.φ.interval.left
            elseif φ_rad < g.φ.interval.left
                φ_rad += g.φ.interval.right - g.φ.interval.left
            end
        end
        :φ, searchsortednearest(g.φ, φ_rad)
    elseif ismissing(φ) && !ismissing(r) && ismissing(z)
        :r, searchsortednearest(g.r, T(r))
    elseif ismissing(φ) && ismissing(r) && !ismissing(z)
        :z, searchsortednearest(g.z, T(z))
    else
        error(ArgumentError, ": Only one of the keywords `r, φ, z` is allowed.")
    end

    value::T = if cross_section == :φ
        rad2deg(g.φ[idx])
    elseif cross_section == :r
        g.r[idx]
    elseif cross_section == :z
        g.z[idx]
    end

    cross_section, idx, value
end



@recipe function f(ep::ElectricPotential{T,3,:cylindrical}; r = missing, φ = missing, z = missing, contours_equal_potential = false) where {T <: SSDFloat}

    if !(ep.grid[2][end] - ep.grid[2][1] ≈ 2π) ep = get_2π_potential(ep, n_points_in_φ = 72) end

    g::Grid{T, 3, :cylindrical} = ep.grid
    cross_section::Symbol, idx::Int, value::T = get_crosssection_idx_and_value(g, r, φ, z)

    seriescolor --> :viridis
    title --> "Electric Potential @ $(cross_section) = $(round(value,sigdigits=2))"*(cross_section == :φ ? "°" : "m")

    ep, cross_section, idx, value, contours_equal_potential
end


@recipe function f(wp::WeightingPotential{T,3,:cylindrical}; r = missing, φ = missing, z = missing) where {T <: SSDFloat}

    if !(wp.grid[2][end] - wp.grid[2][1] ≈ 2π)
        wp = get_2π_potential(wp, n_points_in_φ = 72)
    end

    g::Grid{T, 3, :cylindrical} = wp.grid
    cross_section::Symbol, idx::Int, value::T = get_crosssection_idx_and_value(g, r, φ, z)

    seriescolor --> :viridis
    clims --> (0,1)
    title --> "Weighting Potential @ $(cross_section) = $(round(value,sigdigits=2))"*(cross_section == :φ ? "°" : "m")

    wp, cross_section, idx, value
end


@recipe function f(ρ::EffectiveChargeDensity{T,3,:cylindrical}; r = missing, φ = missing, z = missing) where {T <: SSDFloat}

    if !(ρ.grid[2][end] - ρ.grid[2][1] ≈ 2π)
        ρ = get_2π_potential(ρ, n_points_in_φ = 72)
    end

    g::Grid{T, 3, :cylindrical} = ρ.grid
    cross_section::Symbol, idx::Int, value::T = get_crosssection_idx_and_value(g, r, φ, z)

    seriescolor --> :inferno
    title --> "Effective Charge Density @ $(cross_section) = $(round(value,sigdigits=2))"*(cross_section == :φ ? "°" : "m")

    ρ, cross_section, idx, value
end


@recipe function f(pt::PointTypes{T,3,:cylindrical}; r = missing, φ = missing, z = missing) where {T <: SSDFloat}

    if !(pt.grid[2][end] - pt.grid[2][1] ≈ 2π)
        pt = get_2π_potential(pt, n_points_in_φ = 72)
    end

    g::Grid{T, 3, :cylindrical} = pt.grid
    cross_section::Symbol, idx::Int, value::T = get_crosssection_idx_and_value(g, r, φ, z)

    seriescolor --> :viridis
    clims --> (0,7)
    title --> "Point Type Map @ $(cross_section) = $(round(value,sigdigits=2))"*(cross_section == :φ ? "°" : "m")

    pt, cross_section, idx, value
end

@recipe function f(sp::ScalarPotential{T,3,:cylindrical}, cross_section::Symbol, idx::Int, value::T, contours_equal_potential::Bool = false; resample = true) where {T <: SSDFloat}
    g::Grid{T, 3, :cylindrical} = sp.grid
    @series begin
        seriestype := :heatmap
        foreground_color_border --> nothing
        tick_direction --> :out
        if cross_section == :φ
            aspect_ratio --> 1
            xguide --> "r / m"
            yguide --> "z / m"
            xlims --> (g.r[1],g.r[end])
            ylims --> (g.z[1],g.z[end])
            gr_ext::Array{T,1} = midpoints(get_extended_ticks(g.r))
            gz_ext::Array{T,1} = midpoints(get_extended_ticks(g.z))
            midpoints(gr_ext), midpoints(gz_ext), sp.data[:,idx,:]'
        elseif cross_section == :r
            xguide --> "φ / °"
            yguide --> "z / m"
            ylims --> (g.z[1],g.z[end])
            g.φ, g.z, sp.data[idx,:,:]'
        elseif cross_section == :z
            projection --> :polar
            if resample
                #resample the data as non-uniform polar heatmaps are not shown correctly in GR
                #this can be removed if implemented in GR
                resample_gr::Vector{T} = range(g.r[1], g.r[end], step = (g.r[end] - g.r[1])/(5*length(g.r)))
                resample_gφ::Vector{T} = range(g.φ[1], g.φ[end], step = (g.φ[end] - g.φ[1])/(5*length(g.φ)))
                @info "Data is resampled to correctly display non-uniform polar plot in GR.\n"*
                      "If this is not required, please use the keyword argument `resample = false`\n"*
                      "Points in r: $(length(resample_gr))\nPoints in φ: $(length(resample_gφ))"
                ridx = map(x -> searchsortednearest(g.r, x), resample_gr)
                φidx = map(x -> searchsortednearest(g.φ, x), resample_gφ)
                resample_gφ, resample_gr, sp.data[ridx, φidx, idx]
            else
                g.φ, g.r, sp.data[:,:,idx]
            end
        end
    end
    
    if contours_equal_potential && cross_section == :φ
        @series begin
            seriescolor := :thermal
            seriestype := :contours
            #if cross_section == :φ
                aspect_ratio --> 1
                xguide := "r / m"
                yguide := "z / m"
                xlims --> (g.r[1],g.r[end])
                ylims --> (g.z[1],g.z[end])
                g.r, g.z, sp.data[:,idx,:]'
                #=
            elseif cross_section == :r
                xguide --> "φ / °"
                yguide --> "z / m"
                ylims --> (g.z[1],g.z[end])
                g.φ, g.z, sp.data[idx,:,:]'
            elseif cross_section == :z
                projection --> :polar
                g.φ, g.r, sp.data[:,:,idx]
            end
            =#
        end
    end
end



@recipe function f(ϵ::DielectricDistribution{T,3,:cylindrical}; φ = 0) where {T <: SSDFloat}

    g::Grid{T, 3, :cylindrical} = ϵ.grid
    cross_section::Symbol, idx::Int, value::T = get_crosssection_idx_and_value(g, missing, φ, missing)

    seriestype --> :heatmap
    seriescolor --> :inferno
    foreground_color_border --> nothing
    tick_direction --> :out
    title --> "Dielectric Distribution @ $(cross_section) = $(round(value,sigdigits=2))"*(cross_section == :φ ? "°" : "m")

    gr_ext::Array{T,1} = midpoints(get_extended_ticks(g.r))
    gφ_ext::Array{T,1} = midpoints(get_extended_ticks(g.φ))
    gz_ext::Array{T,1} = midpoints(get_extended_ticks(g.z))

    @series begin
        if cross_section == :φ
            aspect_ratio --> 1
            xguide --> "r / m"
            yguide --> "z / m"
            xlims --> (g.r[1],g.r[end])
            ylims --> (g.z[1],g.z[end])
            gr_ext, gz_ext, ϵ.data[:,idx,:]'
        elseif cross_section == :r
            xguide --> "φ / °"
            yguide --> "z / m"
            ylims --> (g.z[1],g.z[end])
            rad2deg_backend.(gφ_ext), gz_ext, ϵ.data[idx,:,:]'
        elseif cross_section == :z
            projection --> :polar
            rad2deg_backend.(gφ_ext), gr_ext, ϵ.data[:,:,idx]
        end
    end
end



function get_crosssection_idx_and_value(g::Grid{T, 3, :cartesian}, x, y, z)::Tuple{Symbol,Int,T} where {T <: SSDFloat}

    cross_section::Symbol, idx::Int = if ismissing(x) && ismissing(y) && ismissing(z)
        :y, 1
    elseif !ismissing(x) && ismissing(y) && ismissing(z)
        :x, searchsortednearest(g.x, T(x))
    elseif ismissing(x) && !ismissing(y) && ismissing(z)
        :y, searchsortednearest(g.y, T(y))
    elseif ismissing(x) && ismissing(y) && !ismissing(z)
        :z, searchsortednearest(g.z, T(z))
    else
        error(ArgumentError, ": Only one of the keywords `x, y, z` is allowed.")
    end
    value::T = g[cross_section][idx]
    cross_section, idx, value
end

@recipe function f(ep::ElectricPotential{T,3,:cartesian}; x = missing, y = missing, z = missing, contours_equal_potential = false) where {T <: SSDFloat}
    g::Grid{T, 3, :cartesian} = ep.grid
    cross_section::Symbol, idx::Int, value::T = get_crosssection_idx_and_value(g, x, y, z)

    seriescolor --> :viridis
    title --> "Electric Potential @ $(cross_section) = $(round(value,sigdigits=2))m"

    ep, cross_section, idx, value, contours_equal_potential
end

@recipe function f(wp::WeightingPotential{T,3,:cartesian}; x = missing, y = missing, z = missing) where {T <: SSDFloat}

    g::Grid{T, 3, :cartesian} = wp.grid
    cross_section::Symbol, idx::Int, value::T = get_crosssection_idx_and_value(g, x, y, z)

    seriescolor --> :viridis
    clims --> (0,1)
    title --> "Weighting Potential @ $(cross_section) = $(round(value,sigdigits=2))m"

    wp, cross_section, idx, value
end


@recipe function f(ρ::EffectiveChargeDensity{T,3,:cartesian}; x = missing, y = missing, z = missing) where {T <: SSDFloat}
    g::Grid{T, 3, :cartesian} = ρ.grid
    cross_section::Symbol, idx::Int, value::T = get_crosssection_idx_and_value(g, x, y, z)

    seriescolor --> :inferno
    title --> "Effective Charge Density @ $(cross_section) = $(round(value,sigdigits=2))m"

    ρ, cross_section, idx, value
end


@recipe function f(pt::PointTypes{T,3,:cartesian}; x = missing, y = missing, z = missing) where {T <: SSDFloat}

    g::Grid{T, 3, :cartesian} = pt.grid
    cross_section::Symbol, idx::Int, value::T = get_crosssection_idx_and_value(g, x, y, z)

    seriescolor --> :viridis
    clims --> (0,7)
    title --> "Point Type Map @ $(cross_section) = $(round(value,sigdigits=2))m"

    pt, cross_section, idx, value
end


@recipe function f(sp::ScalarPotential{T,3,:cartesian}, cross_section::Symbol, idx::Int, value::T, contours_equal_potential::Bool = false) where {T <: SSDFloat}
    g::Grid{T, 3, :cartesian} = sp.grid
    @series begin
        seriestype := :heatmap
        foreground_color_border --> nothing
        tick_direction --> :out
        if cross_section == :x
            aspect_ratio --> 1
            xguide --> "y / m"
            yguide --> "z / m"
            xlims --> (g.y[1],g.y[end])
            ylims --> (g.z[1],g.z[end])
            gy_ext = midpoints(get_extended_ticks(g.y))
            gz_ext = midpoints(get_extended_ticks(g.z))
            midpoints(gy_ext), midpoints(gz_ext), sp.data[idx,:,:]'
        elseif cross_section == :y
            aspect_ratio --> 1
            xguide --> "x / m"
            yguide --> "z / m"
            xlims --> (g.x[1],g.x[end])
            ylims --> (g.z[1],g.z[end])
            gx_ext = midpoints(get_extended_ticks(g.x))
            gz_ext = midpoints(get_extended_ticks(g.z))
            midpoints(gx_ext), midpoints(gz_ext), sp.data[:,idx,:]'
        elseif cross_section == :z
            aspect_ratio --> 1
            xguide --> "x / m"
            yguide --> "y / m"
            xlims --> (g.x[1],g.x[end])
            ylims --> (g.y[1],g.y[end])
            gx_ext = midpoints(get_extended_ticks(g.x))
            gy_ext = midpoints(get_extended_ticks(g.y))
            midpoints(gx_ext), midpoints(gy_ext), sp.data[:,:,idx]'
        end
    end
    
    if contours_equal_potential
        @series begin
            seriescolor := :thermal
            seriestype := :contours
            aspect_ratio --> 1
            if cross_section == :x
                xguide --> "y / m"
                yguide --> "z / m"
                xlims --> (g.y[1],g.y[end])
                ylims --> (g.z[1],g.z[end])
                gy_ext = midpoints(get_extended_ticks(g.y))
                gz_ext = midpoints(get_extended_ticks(g.z))
                midpoints(gy_ext), midpoints(gz_ext), sp.data[idx,:,:]'
            elseif cross_section == :y
                xguide --> "x / m"
                yguide --> "z / m"
                xlims --> (g.x[1],g.x[end])
                ylims --> (g.z[1],g.z[end])
                gx_ext = midpoints(get_extended_ticks(g.x))
                gz_ext = midpoints(get_extended_ticks(g.z))
                midpoints(gx_ext), midpoints(gz_ext), sp.data[:,idx,:]'
            elseif cross_section == :z
                xguide --> "x / m"
                yguide --> "y / m"
                xlims --> (g.x[1],g.x[end])
                ylims --> (g.y[1],g.y[end])
                gx_ext = midpoints(get_extended_ticks(g.x))
                gy_ext = midpoints(get_extended_ticks(g.y))
                midpoints(gx_ext), midpoints(gy_ext), sp.data[:,:,idx]'
            end
        end
    end
end


@recipe function f(ϵ::DielectricDistribution{T,3,:cartesian}; x = missing, y = missing, z = missing) where {T <: SSDFloat}

    g::Grid{T, 3, :cartesian} = ϵ.grid
    cross_section::Symbol, idx::Int, value::T = get_crosssection_idx_and_value(g, x, y, z)

    seriestype --> :heatmap
    seriescolor --> :inferno
    foreground_color_border --> nothing
    tick_direction --> :out
    title --> "Dielectric Distribution @ $(cross_section) = $(round(value,sigdigits=2))m"

    gx_ext::Array{T,1} = midpoints(get_extended_ticks(g.x))
    gy_ext::Array{T,1} = midpoints(get_extended_ticks(g.y))
    gz_ext::Array{T,1} = midpoints(get_extended_ticks(g.z))

    @series begin
        if cross_section == :x
            aspect_ratio --> 1
            xguide --> "y / m"
            yguide --> "z / m"
            xlims --> (g.y[1],g.y[end])
            ylims --> (g.z[1],g.z[end])
            gy_ext, gz_ext, ϵ.data[idx,:,:]'
        elseif cross_section == :y
            aspect_ratio --> 1
            xguide --> "x / m"
            yguide --> "z / m"
            xlims --> (g.x[1],g.x[end])
            ylims --> (g.z[1],g.z[end])
            gx_ext, gz_ext, ϵ.data[:,idx,:]'
        elseif cross_section == :z
            aspect_ratio --> 1
            xguide --> "x / m"
            yguide --> "y / m"
            xlims --> (g.x[1],g.x[end])
            ylims --> (g.y[1],g.y[end])
            gx_ext, gy_ext, ϵ.data[:,:,idx]'
        end
    end
end
