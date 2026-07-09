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
uniform sampler2D u_ScreenDepthMap;  

uniform vec2 u_InvTexRes;

layout(std140) uniform Camera
{
	mat4 u_viewProjectionMatrix;
	vec4 u_ViewInfo; // x = zFar/zNear, y = zFar
	vec3 u_ViewOrigin;
	vec3 u_ViewForward;
	vec3 u_ViewLeft;
	vec3 u_ViewUp;
};

in vec2 var_TexCoords;
out vec4 out_Color;

// Interleaved Gradient Noise
float GetNoise(vec2 co)
{
    return fract(52.9829189 * fract(dot(co, vec2(0.06711056, 0.00583715))));
}

float getLinearDepth(vec2 tex)
{
	float sampleZDivW = texture(u_ScreenDepthMap, tex).r;
	return 1.0 / mix(u_ViewInfo.x, 1.0, sampleZDivW);
}

// Reconstruct 3D position in View-Space
vec3 GetViewPos(vec2 uv, vec2 fovScale, float zFar)
{
	float z = getLinearDepth(uv) * zFar;
	vec2 clipSpace = uv * 2.0 - 1.0;
	return vec3(clipSpace * z * fovScale, z);
}

void main()
{
	float rawDepth = texture(u_ScreenDepthMap, var_TexCoords).r;

	// Ignore skies and void
	if (rawDepth >= 0.999)
	{
		out_Color = vec4(0.0); 
		return;
	}

	float zFar = u_ViewInfo.y;
	vec2 fovScale = vec2(1.333, 1.0) * (u_InvTexRes.y / u_InvTexRes.x);

	// 1. RECONSTRUCT 3D POSITION AND NORMAL
	vec3 posCenter = GetViewPos(var_TexCoords, fovScale, zFar);
	
	// Hardware derivative math to generate the physical surface normal
	vec3 normal = normalize(cross(dFdx(posCenter), dFdy(posCenter)));
	if (normal.z > 0.0) normal = -normal; // Ensure normals face the camera

	// Build a rotation matrix to orient our rays around the normal
	vec3 up = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	vec3 tangent = normalize(cross(up, normal));
	vec3 bitangent = cross(normal, tangent);
	mat3 TBN = mat3(tangent, bitangent, normal);

	vec3 indirectLight = vec3(0.0);
	float totalHits = 0.0;
	
	float noise = GetNoise(gl_FragCoord.xy);

	// --- TRUE 3D RAY MARCHING ---
	const float GOLDEN_ANGLE = 2.39996323;
	const int numRays = 16;      
	const int numSteps = 5;      
	const float stepSize = 12.0; // Distance per step in JKA units
	const float maxThickness = 15.0; // Prevent rays from hitting the back of thin walls

	for (int i = 0; i < numRays; i++)
	{
		// 2. TRUE VOGEL DISK HEMISPHERE GENERATION
		float r = sqrt(float(i) + 0.5) / sqrt(float(numRays));
		float theta = float(i) * GOLDEN_ANGLE + noise * 6.2831853;
		
		// Map 2D disk to 3D Hemisphere
		vec3 rayLocal = vec3(r * cos(theta), r * sin(theta), sqrt(max(0.0, 1.0 - r*r)));
		vec3 rayDir = TBN * rayLocal; // Orient the ray to bounce OFF the wall

		// 3. MARCH THE RAY IN 3D SPACE
		vec3 currentPos = posCenter + rayDir * (noise * stepSize);

		for (int j = 1; j <= numSteps; j++)
		{
			currentPos += rayDir * stepSize;

			// Project the 3D ray position back to 2D screen UV to sample the depth buffer
			vec2 sampleUV = (currentPos.xy / (currentPos.z * fovScale)) * 0.5 + 0.5;

			if (sampleUV.x < 0.0 || sampleUV.x > 1.0 || sampleUV.y < 0.0 || sampleUV.y > 1.0)
				break;

			float sceneDepth = getLinearDepth(sampleUV) * zFar;

			// 4. TRUE INTERSECTION TEST
			// If our ray's Z is deeper than the scene's Z, we hit a wall!
			float depthDiff = currentPos.z - sceneDepth;

			if (depthDiff > 0.0 && depthDiff < maxThickness) 
			{
				vec3 bounceColor = texture(u_TextureMap, sampleUV).rgb;
				
				// Calculate cosine weight (light is weaker at glancing angles)
				float NdotL = max(dot(normal, rayDir), 0.0);
				
				indirectLight += bounceColor * NdotL;
				totalHits += 1.0;
				break; // Terminate ray after hit
			}
		}
	}

	// 5. CORRECT NORMALIZATION (Only average by successful hits)
	if (totalHits > 0.0)
	{
		indirectLight = (indirectLight / totalHits) * 0.8; // 0.8 overall intensity multiplier
	}

	out_Color = vec4(indirectLight, 1.0);
}
