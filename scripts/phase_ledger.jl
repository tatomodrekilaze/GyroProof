using Printf

function parse_options(args)
    options = Dict(
        "--dt" => "0.1",
        "--steps" => "100",
        "--omega" => "1.0",
        "--output" => "results/phase_ledger.csv",
        "--svg" => "results/phase_ledger.svg",
    )

    if isodd(length(args))
        error("Options need values. Example: --dt 0.1 --steps 100")
    end

    for index in 1:2:length(args)
        name = args[index]
        haskey(options, name) || error("Unknown option: $name")
        options[name] = args[index + 1]
    end

    dt = parse(Float64, options["--dt"])
    steps = parse(Int, options["--steps"])
    omega = parse(Float64, options["--omega"])
    output = options["--output"]
    svg = options["--svg"]

    isfinite(dt) && dt > 0 || error("--dt must be a finite positive number")
    steps > 0 || error("--steps must be a positive integer")
    isfinite(omega) || error("--omega must be finite")

    return (; dt, steps, omega, output, svg)
end

function boris_rotate(vx, vy, omega, dt)
    t = omega * dt / 2
    denominator = 1 + t^2
    cosine_like = (1 - t^2) / denominator
    sine_like = 2 * t / denominator

    return cosine_like * vx + sine_like * vy,
           -sine_like * vx + cosine_like * vy
end

function svg_points(values, left, top, width, height, lower, upper)
    last_index = max(length(values) - 1, 1)
    return join((
        @sprintf("%.2f,%.2f",
            left + (index - 1) * width / last_index,
            top + (upper - value) * height / (upper - lower))
        for (index, value) in enumerate(values)
    ), " ")
end

function draw_panel(file, title, values, left, top, width, height,
                    lower, upper, color, time_end, unit)
    println(file, "<text class=\"axis-title\" x=\"$left\" y=\"$(top - 14)\">$title</text>")

    for tick in 0:4
        fraction = tick / 4
        y = top + fraction * height
        value = upper - fraction * (upper - lower)
        label = @sprintf("%.3g", value)
        @printf(file, "<line class=\"grid\" x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" />\n",
                left, y, left + width, y)
        println(file, "<text class=\"tick\" x=\"$(left - 12)\" y=\"$(y + 4)\" text-anchor=\"end\">$label</text>")
    end

    if lower < 0 < upper
        zero_y = top + upper * height / (upper - lower)
        @printf(file, "<line class=\"zero\" x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" />\n",
                left, zero_y, left + width, zero_y)
    end

    points = svg_points(values, left, top, width, height, lower, upper)
    println(file, "<polyline class=\"trace\" stroke=\"$color\" points=\"$points\" />")
    println(file, "<text class=\"tick\" x=\"$left\" y=\"$(top + height + 20)\">0</text>")
    @printf(file, "<text class=\"tick\" x=\"%.2f\" y=\"%.2f\" text-anchor=\"end\">%.4g %s</text>\n",
            left + width, top + height + 20, time_end, unit)
end

function write_svg(path, times, phase_errors, speed_errors, dt, omega)
    absolute_path = abspath(path)
    mkpath(dirname(absolute_path))

    width = 1040
    height = 600
    left = 104.0
    chart_width = 870.0
    phase_top = 156.0
    phase_height = 170.0
    speed_top = 400.0
    speed_height = 116.0
    phase_limit = max(maximum(abs, phase_errors) * 1.15, 1e-12)
    speed_limit = max(maximum(abs, speed_errors) * 1.2, 1e-12)
    time_end = times[end]

    open(absolute_path, "w") do file
        println(file, """<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height" role="img" aria-labelledby="title description">""")
        println(file, "<title id=\"title\">GyroProof phase and speed ledger</title>")
        println(file, "<desc id=\"description\">A Julia simulation compares the Boris velocity angle with the exact uniform-field angle. Speed drift remains near floating-point roundoff while phase error accumulates.</desc>")
        println(file, """<style>
            text { font-family: Segoe UI, Arial, sans-serif; }
            .background { fill: #f7f8fa; }
            .heading { fill: #162333; font-size: 23px; font-weight: 650; }
            .subheading { fill: #536273; font-size: 13px; }
            .panel { fill: #ffffff; stroke: #d8dee6; stroke-width: 1; }
            .axis-title { fill: #263748; font-size: 13px; font-weight: 600; }
            .tick { fill: #687889; font-size: 11px; }
            .grid { stroke: #e7ebf0; stroke-width: 1; }
            .zero { stroke: #98a5b3; stroke-width: 1; stroke-dasharray: 4 4; }
            .trace { fill: none; stroke-width: 2.5; stroke-linejoin: round; stroke-linecap: round; }
            .foot { fill: #536273; font-size: 12px; }
        </style>""")
        println(file, "<rect class=\"background\" width=\"$width\" height=\"$height\" rx=\"14\" />")
        println(file, "<text class=\"heading\" x=\"44\" y=\"47\">Gyrophase audit</text>")
        @printf(file, "<text class=\"subheading\" x=\"44\" y=\"72\">Uniform magnetic field · dt = %.4g · omega = %.4g rad/s · %d steps</text>\n",
                dt, omega, length(times) - 1)
        println(file, "<rect class=\"panel\" x=\"42\" y=\"101\" width=\"956\" height=\"250\" rx=\"8\" />")
        println(file, "<rect class=\"panel\" x=\"42\" y=\"366\" width=\"956\" height=\"198\" rx=\"8\" />")

        draw_panel(file, "Signed phase error (rad)", phase_errors,
                   left, phase_top, chart_width, phase_height,
                   -phase_limit, phase_limit, "#1677b8", time_end, "s")
        draw_panel(file, "Speed drift from initial speed", speed_errors,
                   left, speed_top, chart_width, speed_height,
                   -speed_limit, speed_limit, "#b87917", time_end, "s")
        println(file, "<text class=\"foot\" x=\"44\" y=\"584\">Lean proves the exact map preserves speed; this plot shows floating-point results and phase error for this run.</text>")
        println(file, "</svg>")
    end

    return absolute_path
end

function write_ledger(path, svg_path, dt, steps, omega)
    absolute_path = abspath(path)
    mkpath(dirname(absolute_path))

    vx = 1.0
    vy = 0.0
    numerical_phase = 0.0
    initial_speed = hypot(vx, vy)
    times = Float64[0.0]
    phase_errors = Float64[0.0]
    speed_errors = Float64[0.0]

    open(absolute_path, "w") do file
        println(file, "step,time,simulated_speed,exact_phase,numerical_phase,phase_error")
        @printf(file, "0,%.12g,%.12g,%.12g,%.12g,%.12g\n",
                0.0, initial_speed, 0.0, numerical_phase, 0.0)

        for step in 1:steps
            old_vx = vx
            old_vy = vy
            vx, vy = boris_rotate(old_vx, old_vy, omega, dt)

            # The signed angle between consecutive velocities avoids phase
            # wrapping and remains within (-pi, pi) for this rotation map.
            cross = old_vx * vy - old_vy * vx
            dot = old_vx * vx + old_vy * vy
            numerical_phase += atan(cross, dot)

            time = step * dt
            exact_phase = -omega * time
            phase_error = numerical_phase - exact_phase
            speed = hypot(vx, vy)
            push!(times, time)
            push!(phase_errors, phase_error)
            push!(speed_errors, speed - initial_speed)

            @printf(file, "%d,%.12g,%.12g,%.12g,%.12g,%.12g\n",
                    step, time, speed, exact_phase, numerical_phase, phase_error)
        end
    end

    svg_file = write_svg(svg_path, times, phase_errors, speed_errors, dt, omega)
    return absolute_path, svg_file, hypot(vx, vy), numerical_phase,
           numerical_phase + omega * steps * dt
end

function main(args)
    options = parse_options(args)
    path, svg_path, final_speed, final_phase, final_error = write_ledger(
        options.output, options.svg, options.dt, options.steps, options.omega
    )

    println("Wrote phase ledger: $path")
    println("Wrote plot: $svg_path")
    @printf("Final speed: %.12g\n", final_speed)
    @printf("Final numerical phase: %.12g rad\n", final_phase)
    @printf("Final signed phase error: %.12g rad\n", final_error)
end

main(ARGS)
