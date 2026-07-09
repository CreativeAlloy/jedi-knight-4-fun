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

// =========================================================================
// --- JKFF SANITY CHECK TOGGLE ---
// Set to 1 to use your Per-Channel Bloom (Vibrant, saturated color halos).
// Set to 0 to use my Unified Scalar Bloom (Standard monochrome-brightness halos).
// =========================================================================
#define USE_PER_CHANNEL_BLOOM 1

void main()
{
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

	// Check the Secret Alpha channel message to identify Pass 1
	float centerAlpha = texture(u_TextureMap, var_TexCoords).a;
	bool isFirstPass = (abs(centerAlpha - 0.5) > 0.1);

	if (isFirstPass)
	{
#if USE_PER_CHANNEL_BLOOM
		// A. PER-CHANNEL ISOLATION CONCEPT (Vivid colors, dynamically saturated)
		// Calculate the exponential curve for R, G, and B independently...
		vec3 channelFactor = pow(min(vec3(1.0), color), vec3(5.0));
		
		// ...then multiply the original HDR color by those factors!
		color *= channelFactor;
#else
		// B. UNIFIED SCALAR CONCEPT (Desaturated, pale monochrome-gradient halos)
		float brightness = max(color.r, max(color.g, color.b));
		float factor = pow(min(1.0, brightness), 5.0); 
		color *= factor;
#endif
	}

	// --- ANTI-SUPERNOVA DEFENSE ---
	color = min(color, vec3(2.0));

	// 4. Output the blurred color, and FORCE the alpha to 0.5!
	out_Color = vec4(color, 0.5);
}
