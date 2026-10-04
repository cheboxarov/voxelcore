#param float p_radius = 2.2

vec4 effect() {
    vec2 px = 1.0 / vec2(u_screenSize);
    float edge = smoothstep(0.05, 0.55, length(v_uv - vec2(0.5)));
    float radius = p_radius * (0.7 + 1.5 * edge) * u_intensity;
    vec3 sum = texture(u_screen, v_uv).rgb * 0.16;
    float total = 0.16;
    for (int i = 0; i < 12; i++) {
        float a = float(i) * 0.5235988;
        vec2 dir = vec2(cos(a), sin(a)) * px * radius;
        sum += texture(u_screen, v_uv + dir).rgb * 0.05;
        sum += texture(u_screen, v_uv + dir * 2.0).rgb * 0.02;
        total += 0.07;
    }
    return vec4(sum / total, 1.0);
}
