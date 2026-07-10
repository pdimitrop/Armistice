shader_type canvas_item;

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float vignette = 1.0 - smoothstep(0.3, 0.9, length(uv) * 1.0);
    COLOR = vec4(0.0, 0.0, 0.0, 1.0 - vignette);
}