shader_type sky;

// Random function
float hash12(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void sky() {
	vec3 dir = EYEDIR;
    
    // Map sphere to 2D UV
    float theta = acos(dir.y) / 3.14159; // 0 to 1
    float phi = atan(dir.z, dir.x) / (2.0 * 3.14159) + 0.5; // 0 to 1
    
    // Create a grid of "tiles"
    float scale = 300.0;
    vec2 uv = vec2(phi, theta) * scale;
    vec2 id = floor(uv);
    vec2 subuv = fract(uv) - 0.5; // Center of tile is 0,0
    
    // Random value per tile
    float rnd = hash12(id);
    
    // Probabilistic star
    float star_intensity = 0.0;
    if (rnd > 0.98) { // Fewer stars (top 2%)
        // Distance from center of tile
        float d = length(subuv);
        // Star size logic
        float size = 0.05 + (rnd - 0.98) * 10.0;
        
        if (d < size) {
             star_intensity = 1.0 - (d / size); // Soft edge
             star_intensity = pow(star_intensity, 3.0);
        }
    }
    
    // Sun Logic
    // Direction based on DirectionalLight in World scene
    // Z basis was (0.25, 0.866, -0.433)
    vec3 sun_dir = normalize(vec3(0.25, 0.866, -0.433));
    float sun_dot = dot(EYEDIR, sun_dir);
    float sun_radius = 0.01; // Size of sun disk
    float sun_intensity = 0.0;
    
    if (sun_dot > (1.0 - sun_radius)) {
        sun_intensity = 1.0;
    }
    // Sun Glow
    float sun_glow = clamp((sun_dot - 0.95) * 20.0, 0.0, 1.0);

    vec3 star_color = vec3(star_intensity); // No twinkle, just static intensity
    vec3 sky_bg = vec3(0.0, 0.0, 0.015); // Very dark blue
    
    // Combine
    vec3 sun_color = vec3(1.0, 1.0, 0.8) * (sun_intensity + sun_glow * 0.5);
    
    // Mask stars behind sun
    if (sun_intensity > 0.1) {
        star_color = vec3(0.0);
    }
    
    COLOR = sky_bg + star_color + sun_color;
}
