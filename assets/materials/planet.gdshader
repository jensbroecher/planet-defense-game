shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness : hint_range(0, 1) = 0.8;
uniform float specular : hint_range(0, 1) = 0.5;

uniform vec3 uv1_scale = vec3(1.0);
uniform float patch_scale = 0.05;
uniform float patch_darkness : hint_range(0.0, 1.0) = 0.3;
uniform float patch_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float patch_edge_softness : hint_range(0.0, 1.0) = 0.1;

varying vec3 uv1_power_normal;
varying vec3 uv1_triplanar_pos;

// Simplex 3D noise (standard implementation)
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x * 34.0) + 1.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float snoise(vec3 v) {
    const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

    // First corner
    vec3 i = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);

    // Other corners
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);

    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
    vec3 x3 = x0 - D.yyy;      // -1.0 + 3.0*C.x = -0.5 = -D.y

    // Permutations
    i = mod289(i);
    vec4 p = permute(permute(permute(
             i.z + vec4(0.0, i1.z, i2.z, 1.0))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0))
           + i.x + vec4(0.0, i1.x, i2.x, 1.0));

    // Gradients: 7x7 points over a square, mapped onto an octahedron.
    // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
    float n_ = 0.142857142857; // 1.0/7.0
    vec3 ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);  //  mod(p,7*7)

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);    // mod(j,N)

    vec4 x = x_ * ns.x + ns.yyyy;
    vec4 y = y_ * ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);

    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);

    // Normalise gradients
    vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    // Mix final noise value
    vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

void vertex() {
    TANGENT = vec3(0.0, 0.0, -1.0) * abs(NORMAL.x);
    TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.y);
    TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.z);
    TANGENT = normalize(TANGENT);
    
    BINORMAL = vec3(0.0, 1.0, 0.0) * abs(NORMAL.x);
    BINORMAL += vec3(0.0, 0.0, -1.0) * abs(NORMAL.y);
    BINORMAL += vec3(0.0, 1.0, 0.0) * abs(NORMAL.z);
    BINORMAL = normalize(BINORMAL);
    
    uv1_power_normal = pow(abs(NORMAL), vec3(4.0)); // Sharp blending
    uv1_power_normal /= dot(uv1_power_normal, vec3(1.0));
    uv1_triplanar_pos = VERTEX; // Use local vertex for triplanar to stick to object
}

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
    vec4 samp = vec4(0.0);
    samp += texture(p_sampler, p_triplanar_pos.xy * uv1_scale.xy) * p_weights.z;
    samp += texture(p_sampler, p_triplanar_pos.xz * uv1_scale.xz) * p_weights.y;
    samp += texture(p_sampler, p_triplanar_pos.zy * uv1_scale.zy) * p_weights.x;
    return samp;
}

void fragment() {
    // Albedo
    vec4 albedo_tex = triplanar_texture(albedo_texture, uv1_power_normal, uv1_triplanar_pos);
    
    // Noise patches
    // We use vertex position for noise to ensure it stays consistent
    float n = snoise(uv1_triplanar_pos * patch_scale);
    // Normalize noise from [-1, 1] to [0, 1]
    n = n * 0.5 + 0.5;
    
    // Apply threshold to create patches
    float patch_factor = smoothstep(patch_threshold - patch_edge_softness, patch_threshold + patch_edge_softness, n);
    
    // Darken albedo where patches are
    vec3 final_color = albedo_tex.rgb * albedo_color.rgb;
    final_color = mix(final_color, final_color * (1.0 - patch_darkness), patch_factor);
    
    ALBEDO = final_color;
    ROUGHNESS = roughness;
    SPECULAR = specular;
}
