shader_type canvas_item;

uniform vec4 shine_color : source_color = vec4(1.0);
uniform float alpha_limit : hint_range(0.0, 1.0, 0.1) = 0.0;
uniform float cycle_speed : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform bool full_pulse_cycle = true; 
uniform float mode : hint_range(0.0, 2.0, 0.01) = 0.0; 

// CHANGED: Replaced global TIME with a controlled uniform
uniform float custom_time = 1.0; 

void fragment()
{
	if (COLOR.a >= alpha_limit)
	{
		// FIX: Using custom_time instead of TIME
		float cycle = sin(custom_time * cycle_speed);
		float pulse_intensity = (((cycle >= 0.0) || (full_pulse_cycle)) ? abs(cycle) : 0.0) * shine_color.a;
		vec3 pulse_color = mix(COLOR.rgb, shine_color.rgb, pulse_intensity);
		
		vec3 always_on_color = mix(COLOR.rgb, shine_color.rgb, shine_color.a);
		vec3 final_rgb = COLOR.rgb;
		
		if (mode <= 1.0) {
			final_rgb = mix(COLOR.rgb, pulse_color, mode);
		} else {
			final_rgb = mix(pulse_color, always_on_color, mode - 1.0);
		}
		
		COLOR.rgb = final_rgb;
	}
}