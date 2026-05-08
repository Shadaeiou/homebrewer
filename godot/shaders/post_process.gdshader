shader_type canvas_item;

// Full-screen post-process applied as a CanvasLayer at the top of the scene
// tree. Reads the already-drawn screen, applies vignette + warm color grade
// + cheap pseudo-bloom + film noise, writes the composited frame.
//
// Designed to run on gl_compatibility (mobile path). 8-tap bloom approximation
// rather than a real multi-pass blur — readable, performant, "good enough for
// 2D" — see the writeup in CLAUDE.md.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.35;

uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.65;
uniform float bloom_strength : hint_range(0.0, 2.0) = 0.55;
uniform float bloom_radius_px : hint_range(1.0, 16.0) = 5.0;

uniform float warm_shift : hint_range(-0.1, 0.1) = 0.025;
uniform float contrast : hint_range(0.5, 1.5) = 1.06;
uniform float saturation : hint_range(0.5, 1.5) = 1.08;

uniform float noise_strength : hint_range(0.0, 0.05) = 0.012;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 apply_grade(vec3 c) {
	// Contrast around mid-grey
	c = (c - 0.5) * contrast + 0.5;
	// Warm push: nudge red up, blue down (subtle "kitchen warm" mood)
	c.r += warm_shift;
	c.b -= warm_shift * 0.6;
	// Saturation around luminance
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(l), c, saturation);
	return clamp(c, 0.0, 1.0);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// ---- Pseudo-bloom (8-tap radial sample of bright pixels) ---------------
	vec2 px = 1.0 / vec2(textureSize(screen_tex, 0));
	vec3 bloom = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853981633;  // PI / 4
		vec2 off = vec2(cos(a), sin(a)) * px * bloom_radius_px;
		vec3 s = texture(screen_tex, SCREEN_UV + off).rgb;
		float lum = dot(s, vec3(0.2126, 0.7152, 0.0722));
		float over = max(lum - bloom_threshold, 0.0);
		bloom += s * over;
	}
	bloom /= 8.0;
	col += bloom * bloom_strength;

	// ---- Color grade ------------------------------------------------------
	col = apply_grade(col);

	// ---- Vignette ---------------------------------------------------------
	vec2 v = SCREEN_UV - 0.5;
	float dist = length(v) * 1.4142;  // normalize so 1.0 at corner
	float vignette = smoothstep(vignette_softness, 1.0, dist);
	col *= 1.0 - vignette * vignette_strength;

	// ---- Film noise (slowly time-varying so it doesn't look static) -------
	float n = (hash(SCREEN_UV * 1500.0 + TIME * 0.07) - 0.5) * noise_strength;
	col += n;

	COLOR = vec4(col, 1.0);
}
