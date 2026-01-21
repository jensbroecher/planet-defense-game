shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.0, 0.3, 0.8);
uniform float metallic : hint_range(0.0, 1.0) = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float wave_speed = 0.1;
uniform float wave_scale = 10.0;
uniform sampler2D noise_texture;

void fragment() {
    vec2 uv = UV * wave_scale;
    vec2 motion = vec2(TIME * wave_speed, TIME * wave_speed * 0.5);
    
    float noise1 = texture(noise_texture, uv + motion).r;
    float noise2 = texture(noise_texture, uv - motion * 0.8 + vec2(0.5)).r;
    
    float combined_noise = (noise1 + noise2) * 0.5;
    
    ALBEDO = albedo;
    METALLIC = metallic;
    ROUGHNESS = roughness + (combined_noise * 0.2);
    NORMAL_MAP = texture(noise_texture, uv + motion).rgb; # Use noise as pseudo-normal for now
    NORMAL_MAP_DEPTH = 0.5;
}
