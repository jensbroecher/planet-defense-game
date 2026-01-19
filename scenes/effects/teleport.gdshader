shader_type spatial;

uniform vec3 albedo_color : source_color = vec3(0.0, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float border_width = 0.05;

void fragment() {
	// Simple vertical wipe from bottom to top based on UV.y or world Y
	// Assuming logic UVs are well mapped, otherwise we might use world position
	
	// Create a "hologram" grid effect
	float grid = step(0.95, fract(UV.x * 20.0)) + step(0.95, fract(UV.y * 20.0));
	vec3 emission = albedo_color * grid * 2.0;
	
	// Dissolve logic
	// We want to dissolve IN, so visible part grows from bottom.
	// We can use VERTEX position or UV depending on the mesh. 
	// Let's use UV.y for simplicity initially, assuming 0 is bottom, 1 is top.
	// progress 0 -> invisible
	// progress 1 -> fully visible
	
	float current_height = UV.y; 
	// Actually for standard box UVs, y goes 0-1 per face, which might look weird on sides.
	// World position is safer for "teleporting in from ground"
	
	// We'll use a screen door transparency or similar, but for "teleport in" 
	// typically you want to see the object materializing.
	
	ALBEDO = albedo_color;
	EMISSION = emission;
	ALPHA = 0.5 + 0.5 * grid; // Semi-transparent base
	
	// Add a glowing rim at the cut-off point
	// Since we are overriding material, we might lose the original texture.
	// As per plan, we are swapping materials or overriding. 
	// Let's make this a "hologram ghost" that transitions to real object.
	// Actually, the plan says "Appear with effect... take 10 seconds".
	// Maybe we should just use the transparency fade and some noise.
	
	// Vertical cut
	// We need the height of the object. 
	// Let's use a simplified approach: Just alpha fade + emission pulse.
	
	float noise = fract(sin(dot(UV, vec2(12.9898, 78.233))) * 43758.5453);
	float alpha_cut = smoothstep(progress - 0.1, progress, noise);
	
	// Alternatively, just a simple mix.
	ALPHA = mix(0.0, 0.8, progress * (0.5 + 0.5 * grid));
	
	// Add a "scanning" line
	float scan_line = step(abs(UV.y - progress), 0.02);
	EMISSION += vec3(1.0, 1.0, 1.0) * scan_line * 5.0;
	
	// Final Flash
	float flash = smoothstep(0.85, 1.0, progress);
	EMISSION += vec3(2.0, 2.0, 2.0) * flash * 10.0;
	// Force alpha to 1 during flash to hide internal geometry if distinct parts
	ALPHA = mix(ALPHA, 1.0, flash);
}
