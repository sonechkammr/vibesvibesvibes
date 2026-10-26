shader_type canvas_item;
uniform float daylight : hint_range(0.0,1.0) = 1.0;
uniform float warmth : hint_range(0.0,1.0) = 0.0;
void fragment() {
    vec4 source = texture(TEXTURE,UV);
    float luma = dot(source.rgb,vec3(0.299,0.587,0.114));
    vec3 night = source.rgb*vec3(0.28,0.40,0.65)+vec3(0.006,0.012,0.035)*luma;
    vec3 lit = mix(night,source.rgb,daylight);
    lit = mix(lit,lit*vec3(1.25,0.86,0.68)+vec3(0.06,0.013,0.005),warmth*0.55);
    // Preserve warm lamps as small emissive accents after sunset.
    float lamp = smoothstep(0.12,0.35,source.r-source.b)*smoothstep(0.48,0.85,source.r);
    lit = mix(lit,source.rgb*vec3(1.05,0.88,0.58),lamp*(1.0-daylight)*0.88);
    COLOR = vec4(lit,source.a);
}
