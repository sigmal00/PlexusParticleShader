Shader "Sigmal00/PlexusParticleStar"
{
	Properties
	{
		[Header(General Settings)]
		[Space(8)]
		[HDR]_Color("Color" , Color) = (1.0, 1.0, 1.0, 1.0)
		[Header(Line Settings)]
		[Space(8)]
		_LineWidth("Line Width", Range(0.0, 1.0)) = 0.5
		_ConnectDist("Connect Distance", Range(0.0, 10.0)) = 1.0
		_FadeDist("Fade Distance", Range(0.0, 5.0)) = 1.0
		[Header(Star Settings)]
		[Space(8)]
		_ParticleSize("Particle Size", Range(0.0, 1.0)) = 1.0
		_InnerRadius("Inner Radius", Range(0.0, 2.0)) = 0.0
		_OuterRadius("Outer Radius", Range(0.0, 1.0)) = 0.0
		_Sharpness("Sharpness", Range(0.0, 2.0)) = 0.0
	}
		SubShader
	{
		Tags 
		{
			 "RenderType" = "Transparent"
			 "Queue" = "Transparent" 
			 "IgnoreProjector" = "True"
		}
		Cull Off
		Blend SrcAlpha One
		Zwrite Off
		LOD 100

		Pass
		{
			CGPROGRAM
// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag
			#pragma multi_compile_instancing
			#pragma instancing_options procedural:vertInstancingSetup

			#define UNITY_PARTICLE_INSTANCE_DATA PlexusParticleInstanceData
			#define UNITY_PARTICLE_INSTANCE_DATA_NO_ANIM_FRAME
			struct PlexusParticleInstanceData
			{
				float3x4 transform;
				uint color;
				float2 attribute;
			};

			#include "UnityCG.cginc"
			#include "UnityStandardParticleInstancing.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float4 color : COLOR;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct g2f
			{
				float2 uv : TEXCOORD0;
				float4 color : TEXCOORD1;
				float attribute : TEXCOORD2;
				float4 vertex : SV_POSITION;
			};

			float _ParticleSize, _LineWidth;
			float _ConnectDist, _FadeDist;
			float _InnerRadius, _OuterRadius;
			float _Sharpness;
		
			inline float rand(float3 co) {
				return frac(sin(dot(co.xyz, float2(12.9898, 78.233))) * 43758.5453);
			};

			inline float2x2 rotate2d(float angle){
			    return float2x2(cos(angle),-sin(angle),
                sin(angle),cos(angle));
			}

			float3 GetScale()
			{
				float scaleX = length(float3(unity_ObjectToWorld[0][0], unity_ObjectToWorld[1][0], unity_ObjectToWorld[2][0]));
				float scaleY = length(float3(unity_ObjectToWorld[0][1], unity_ObjectToWorld[1][1], unity_ObjectToWorld[2][1]));
				float scaleZ = length(float3(unity_ObjectToWorld[0][2], unity_ObjectToWorld[1][2], unity_ObjectToWorld[2][2]));
				return float3(scaleX, scaleY, scaleZ);
			}

			void GetParticleColorByIndex(inout fixed4 color, uint index)
			{
#ifdef UNITY_PARTICLE_INSTANCING_ENABLED
#ifndef UNITY_PARTICLE_INSTANCE_DATA_NO_COLOR
				UNITY_PARTICLE_INSTANCE_DATA data = unity_ParticleInstanceData[index];
				color = lerp(fixed4(1.0f, 1.0f, 1.0f, 1.0f), color, unity_ParticleUseMeshColors);
				color *= float4(data.color & 255, (data.color >> 8) & 255, (data.color >> 16) & 255, (data.color >> 24) & 255) * (1.0f / 255);
#endif
#endif
			}

			appdata vert(appdata v)
			{
				return v;
			}

			[maxvertexcount(85)]
			void geom(triangle appdata IN[3], inout TriangleStream<g2f> TriStream)
			{
				UNITY_SETUP_INSTANCE_ID(IN[0]);

				float3 vpos = UnityObjectToViewPos(float4(0, 0, 0, 1));
				float3 vcenter = vpos;
				float3 viewPos = float(0).xxx;
				float3 offset = float(0).xxx;

				float size = GetScale();
				float4 color = IN[0].color;
				float rotDeg = 0.0f;
#ifdef UNITY_PARTICLE_INSTANCING_ENABLED
				vertInstancingColor(color);
				rotDeg = unity_ParticleInstanceData[unity_InstanceID].attribute.y;
#endif

				g2f o;

				const float2x2 rotMatrix = rotate2d(rotDeg);

				// 本体のビルボード
				// 出力頂点数節約のため正三角形
				o.uv = float2(0.5, -0.5);
				offset = _ParticleSize * float3(float2(0.0, -1.0)*size, 0.0);
				offset.xy = mul(rotMatrix, offset.xy);
				o.vertex = mul(UNITY_MATRIX_P, float4(vpos + offset, 1.0f));
				o.color = color;
				o.attribute = 0.0f;
				TriStream.Append(o);

				o.uv = float2(0.5 - 1.7321*0.5, 1.0);
				offset = _ParticleSize * float3(float2(-1.7321*0.5, 0.5)*size, 0.0);
				offset.xy = mul(rotMatrix, offset.xy);
				o.vertex = mul(UNITY_MATRIX_P, float4(vpos + offset, 1.0f));
				o.color = color;
				o.attribute = 0.0f;
				TriStream.Append(o);

				o.uv = float2(0.5 + 1.7321*0.5, 1.0);
				offset = _ParticleSize * float3(float2(1.7321*0.5, 0.5)*size, 0.0);
				offset.xy = mul(rotMatrix, offset.xy);
				o.vertex = mul(UNITY_MATRIX_P, float4(vpos + offset, 1.0f));
				o.color = color;
				o.attribute = 0.0f;
				TriStream.Append(o);

				TriStream.RestartStrip();

#ifdef UNITY_PARTICLE_INSTANCING_ENABLED

				// つなぐ線
				// "自分の位置"から"自分と相手の中点"までライン状のビルボードを伸ばす
				// 　　中点なのはオーバードロー対策
				// 相手の色と自分の色をビルボードの頂点にのっけることで色を補間させる
				// とりあえず最近傍同士だけでつないでみる
				float3 center = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
				float4 cpos = mul(UNITY_MATRIX_P, float4(vpos, 1.0f));

				int outputCount = 0;
				for (uint ii = unity_BaseInstanceID; ii < unity_BaseInstanceID + unity_InstanceCount; ii++)
				{
					if (ii == unity_InstanceID) continue;
					float3 targetPos = unity_ParticleInstanceData[ii].transform._14_24_34;

					float dist = length(targetPos - center);

					float connectDist = _ConnectDist - 0.5*_ConnectDist;
					
					if (dist > connectDist)continue;

					float fade = smoothstep(connectDist, connectDist - _FadeDist, dist);

					targetPos = 0.5*(targetPos - center) + center;
					float4 tarCpos = UnityWorldToClipPos(targetPos);
					float2 targetDir = normalize(tarCpos.xy - cpos.xy);

					float4 offset = _LineWidth * size * float4(-targetDir.y, targetDir.x, 0, 0);

					float4 neighborColor = 1.0;
					GetParticleColorByIndex(neighborColor, ii);
					o.color = color;
					o.attribute = 1.0f;
					o.color.a = min(neighborColor.a, color.a)*fade;

					#define U 0.0f

					// 1st
					o.vertex = cpos + offset;
					o.uv = float2(U, 1);
					TriStream.Append(o);

					// 2nd
					o.vertex = cpos - offset;
					o.uv = float2(U, 0);
					TriStream.Append(o);

					o.color.rgb = (color.rgb + neighborColor.rgb)*0.5;

					// 3rd
					o.vertex = tarCpos + offset;
					o.uv = float2(U + 0.5, 1);
					TriStream.Append(o);

					// 4th
					o.vertex = tarCpos - offset;
					o.uv = float2(U + 0.5, 0);
					TriStream.Append(o);

					TriStream.RestartStrip();

					outputCount++;
				}
#endif
			}

			uniform float4 _Color;

			// https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
			float sdStar5(in float2 p, in float r, in float rf)
			{
				const float2 k1 = float2(0.809016994375, -0.587785252292);
				const float2 k2 = float2(-k1.x,k1.y);
				p.x = abs(p.x);
				p -= 2.0*max(dot(k1,p),0.0)*k1;
				p -= 2.0*max(dot(k2,p),0.0)*k2;
				p.x = abs(p.x);
				p.y -= r;
				float2 ba = rf*float2(-k1.y,k1.x) - float2(0,1);
				float h = clamp( dot(p,ba)/dot(ba,ba), 0.0, r );
				return length(p-ba*h) * sign(p.y*ba.x-p.x*ba.y);
			}

			fixed4 frag(g2f i) : SV_Target
			{
				//clip(offset-sdStar5(i.uv - 0.5f, _InnerRadius, _OuterRadius));
				float c = sdStar5(i.uv - 0.5f, _InnerRadius, _OuterRadius) + _Sharpness;
				float d = 2*((i.attribute < 0.5f) ? max(3.0*c, 0.0f) : length(i.uv - 0.5f));

				float mask = saturate(1.0f - d);
				float glow = pow(d, 2.0f);
				float4 col = float4(mask * clamp(i.color.rgb*_Color.rgb / glow, 0.0f, 2.0f), 1.0f);
				return col* i.color.a*_Color.a;
			}
			ENDCG
		}
	}
}
