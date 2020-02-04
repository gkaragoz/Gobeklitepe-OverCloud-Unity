// A simple example shader showing how to add OverCloud compatibility.

Shader "OverCloud/Transparent"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Color", Color) = (1, 1, 1, 1)
		// This parameter is used to blend the transparent shader with the clouds, based on the cloud depth buffer
		_CloudBlend ("Cloud Blend", Range(0, 1)) = 0.1
	}
	SubShader
	{
		Tags { "RenderType"="Transparent" "Queue"="Transparent" }

		// Alpha blending
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing

			#include "UnityCG.cginc"

			// Navigate to the OverCloud include file, so we can use the necessary functions
			// Note that this assumes OverCloud is located in your root Assets directory
			#include "../OverCloud/OverCloudInclude.cginc"

			struct v2f
			{
				float4 vertex 		: SV_POSITION;
				float4 color		: COLOR;
				float2 texcoord		: TEXCOORD0;

				// OverCloud needs this to sample screen-space textures in the fragment shader
				float4 screenPos	: TEXCOORD1;

				// Add interpolators so we can sample the atmosphere in the vertex shader.
				// The number (1 in this case) should be +1 from the highest TEXCOORDX you are using, where X is the number.
				// Above, 'float2 texcoord : TEXCOORD0' and 'float4 screenPos : TEXCOORD1' are used, so the interpolators 2+ are available.
				// OverCloud uses 3 interpolators, so in this case the interpolators 2, 3 and 4 will be occupied.
				OVERCLOUD_COORDS(2)

				UNITY_VERTEX_OUTPUT_STEREO
			};

			sampler2D 	_MainTex;
			fixed4		_Color;
			float		_CloudBlend;

			v2f vert (appdata_full v)
			{
				UNITY_SETUP_INSTANCE_ID(v);
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f, o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.vertex 	= UnityObjectToClipPos(v.vertex);
				o.color		= v.color;
				o.texcoord 	= v.texcoord;

				// OverCloud needs the world position to calculate effects, so if it is not already available we need to calculate it.
				float3 worldpos = mul(unity_ObjectToWorld, v.vertex);
				// Additionally, the fragment shader needs the screen-space texture coordinates.
				o.screenPos = ComputeScreenPos(o.vertex);
				// The cloud blending function also needs the distance from the camera.
				// Since o.screenPos.z is not used for anything, we store it here
				o.screenPos.z = length(worldpos - _WorldSpaceCameraPos);
				// Sample the atmosphere and fog
				OVERCLOUD_TRANSFER(worldpos, o)

				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);

				fixed4 albedo = tex2D(_MainTex, i.texcoord);

				fixed4 color = albedo * i.color * _Color;

				// Screen-space texture coordinates
				float2 screenUV = i.screenPos.xy / i.screenPos.w;

				float distFromCamera = i.screenPos.z;

				// Apply the atmosphere + fog at the end of the fragment shader
				OVERCLOUD_FRAGMENT(color.rgb, screenUV);

				// This will enable blending with the clouds
				color.a *= CloudAttenuation(distFromCamera, screenUV, _CloudBlend);
				
				return color;
			}
			ENDCG
		}
	}
}