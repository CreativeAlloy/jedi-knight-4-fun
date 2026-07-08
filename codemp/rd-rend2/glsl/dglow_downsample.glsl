/*[Vertex]*/
out vec2 var_TexCoords;

void main()
{
	const vec2 positions[] = vec2[3](
		vec2(-1.0f, -1.0f),
		vec2(-1.0f,  3.0f),
		vec2( 3.0f, -1.0f)
	);

	const vec2 texcoords[] = vec2[3](
		vec2( 0.0f,  1.0f),
		vec2( 0.0f, -1.0f),
		vec2( 2.0f,  1.0f)
	);

	gl_Position = vec4(positions[gl_VertexID], 0.0, 1.0);
	var_TexCoords = texcoords[gl_VertexID];
}

/*[Fragment]*/
uniform sampler2D u_TextureMap;
uniform vec2 u_InvTexRes;

in vec2 var_TexCoords;

out vec4 out_Color;

void main()
{
	// 1. THE ITERATIVE HACK
	// Check the alpha channel of the center pixel. 
	// If it is exactly 0.5, we wrote it during the previous blur pass, so we skip the threshold!
	float centerAlpha = texture(u_TextureMap, var_TexCoords).a;
	bool isFirstPass = (abs(centerAlpha - 0.5) > 0.1);

	// Based on "Next Generation Post Processing in Call of Duty: Advanced Warfare":
	// http://advances.realtimerendering.com/s2014/index.html
	vec3 color = vec3(0.0);
	color += 0.25 * 0.125 * texture(u_TextureMap, var_TexCoords + (u_InvTexRes * vec2(-2.0, -2.0))).rgb;
	color += 0.5 * 0.25 * texture(u_TextureMap, var_TexCoords + (u_InvTexRes * vec2( 0.0, -2.0))).rgb;
	color += 0.25 * 0.125 * texture(u_TextureMap, var_TexCoords + (u_InvTexRes * vec2( 2.0, -2.0))).rgb;
	color += 0.25 * 0.5 * texture(u_TextureMap, var_TexCoords + (u_InvTexRes * vec2(-1.0, -1.0))).rgb;
	color += 0.25 * 0.5 * texture(u_TextureMap, var_TexCoords + (u_InvTexRes * vec2( 1.0, -1.0))).rgb;
	color += 0.25 * 0.125 * texture(u_TextureMap, var_TexCoords + (u_InvTexRes * vec2(-2.0,  0.0))).rgb;
	color += 0.125 * texture(u_TextureMap, var_TexCoords + (u_InvTexRes * vec2( 0.0,  0.0))).rgb;
	
	// FIXED OPENJK TYPO: Changed vec2(2.0, -2.0) to vec2(2.0, 0.0)
	color += 0.25 * 0.125 * texture(u_TextureMap, var_TexCoords + (u_InvTexRes * vec2( 2.0,  0.0))).rgb;
	
	color += 0.25 * 0.5 * texture(u_TextureMap, var_TexCoords + (u_InvTexRes * vec2(-1.0,  1.0))).rgb;
	color += 0.25 * 0.5 * texture(u_TextureMap, var_TexCoords + (u_InvTexRes * vec2( 1.0,  1.0))).rgb;
	color += 0.25 * 0.125 * texture(u_TextureMap, var_TexCoords + (u_InvTexRes * vec2(-2.0,  2.0))).rgb;
	color += 0.5 * 0.25 * texture(u_TextureMap, var_TexCoords + (u_InvTexRes * vec2( 0.0,  2.0))).rgb;
	color += 0.25 * 0.125 * texture(u_TextureMap, var_TexCoords + (u_InvTexRes * vec2( 2.0,  2.0))).rgb;

	// 3. THRESHOLD ONLY ON FIRST PASS
	if (isFirstPass)
	{
		float brightness = max(color.r, max(color.g, color.b));
		float factor = pow(min(1.0, brightness), 5.0); 
		color *= factor;
	}

	// --- ANTI-SUPERNOVA DEFENSE ---
	// Cap the maximum possible brightness that can enter the blur passes.
	// This prevents bugged engine particles (like the Repeater alt-fire) 
	// from carrying RGB values of 5000.0 and stamping solid white squares.
	// Lowered from 10.0 to prevent overlapping additive effects
	// (like Force Lightning) from blooming into a solid white blob.
	color = min(color, vec3(1.5));

	// 4. Output the blurred color, and FORCE the alpha to 0.5!
	out_Color = vec4(color, 0.5);
}
