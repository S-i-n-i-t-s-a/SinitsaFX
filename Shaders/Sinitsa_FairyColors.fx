/*=============================================================================
  Based on "Blooming HDR" by Jose Negrete AKA BlueSkyDefender
  License: CC BY-SA 4.0 (Attribution-ShareAlike 4.0 International)
=============================================================================*/

#include "ReShade.fxh"

//----------|
// :: UI :: |
//----------|

uniform float HDR_BP <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.05;
    ui_label = "HDR Power (HDR_BP)";
    ui_tooltip = "You don't need this.";
> = 0.0;

uniform float Contrast <
    ui_type = "drag";
    ui_min = 0.50; ui_max = 1.50; ui_step = 0.01;
    ui_label = "Contrast";
    ui_tooltip = "You don't need this.";
> = 0.95;

uniform float MidtoneCompress <
    ui_type = "drag";
    ui_min = 0.05; ui_max = 0.25; ui_step = 0.01;
    ui_label = "Midtone Black Anchor";
    ui_tooltip = "You don't need this.";
> = 0.12;

uniform float Saturate <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 5.0; ui_step = 0.05;
    ui_label = "Image Saturation";
    ui_tooltip = "You need this.";
> = 1.0;

uniform float Exposure <
    ui_type = "drag";
    ui_min = -4.0; ui_max = 4.0; ui_step = 0.1;
    ui_label = "Exposure Bias";
    ui_tooltip = "You don't need this.";
> = 0.3;

uniform float Gamma <
    ui_type = "drag";
    ui_min = 1.0; ui_max = 4.0; ui_step = 0.1;
    ui_label = "Gamma Value";
    ui_tooltip = "You don't need this.";
> = 1.0;

uniform float WP <
    ui_type = "drag";
    ui_min = 0.00; ui_max = 2.00; ui_step = 0.05;
    ui_label = "Linear White Point";
    ui_tooltip = "You don't need this.";
> = 1.0;

//-------------------|
// :: Something ::   |
//-------------------|

namespace TimothyColorHDR
{
    
    sampler sBackBufferPoint
    {
        Texture = ReShade::BackBufferTex;
        MinFilter = POINT;
        MagFilter = POINT;
        MipFilter = POINT;
    };

    float3 InvTonemapColor(float3 color, float hdrBP)
    {
        float w = 1.0 - hdrBP;
        return color * rcp(max((1.0 + w) - color, 0.001));
    }

    float ColToneB(float hdrMax, float contrast, float shoulder, float midIn, float midOut)
    {
        return -((-pow(midIn, contrast) + (midOut*(pow(hdrMax, contrast*shoulder)*pow(midIn, contrast) -
                pow(hdrMax, contrast)*pow(midIn, contrast*shoulder)*midOut)) /
                (pow(hdrMax, contrast*shoulder)*midOut - pow(midIn, contrast*shoulder)*midOut)) /
                (pow(midIn, contrast*shoulder)*midOut));
    }

    float ColToneC(float hdrMax, float contrast, float shoulder, float midIn, float midOut)
    {
        return (pow(hdrMax, contrast*shoulder)*pow(midIn, contrast) - pow(hdrMax, contrast)*pow(midIn, contrast*shoulder)*midOut) /
               (pow(hdrMax, contrast*shoulder)*midOut - pow(midIn, contrast*shoulder)*midOut);
    }

    float ColTone(float x, float4 p)
    {
        float z = pow(x, p.r);
        return z / (pow(z, p.g) * p.b + p.a);
    }

    float3 ApplyTimothyTonemap(float3 color)
    {
        float hdrMax = 16.0;
        float contrast = Contrast + 0.250;
        static const float shoulder = 1.0;
        
        // Используем контролируемый порог средних тонов
        float midIn = MidtoneCompress; 
        float midOut = 0.18;

        float b = ColToneB(hdrMax, contrast, shoulder, midIn, midOut);
        float c = ColToneC(hdrMax, contrast, shoulder, midIn, midOut);

        color *= exp2(Exposure);

        #define EPS 1e-6f
        float peak = max(color.r, max(color.g, color.b));
        peak = max(EPS, peak);

        float3 ratio = color / peak;
        peak = ColTone(peak, float4(contrast, shoulder, b, c));

        float crosstalk = 4.0;
        float saturation = Saturate; 
        float crossSaturation = 16.0; 

        ratio = pow(abs(ratio), max(0.001, saturation / crossSaturation));
        ratio = lerp(ratio, WP, pow(peak, crosstalk));
        ratio = pow(abs(ratio), crossSaturation);

        return peak * ratio;
    }

    void PS_TimothyColorHDR(float4 vpos : SV_Position, float2 uv : TEXCOORD, out float4 outColor : SV_Target)
    {
        
        float3 color = tex2D(sBackBufferPoint, uv).rgb;

        
        if (Gamma > 1.0)
            color = pow(abs(color), Gamma);

        
        color = InvTonemapColor(color, HDR_BP);

        
        color = ApplyTimothyTonemap(color);

        
        if (Gamma > 1.0)
            color = pow(abs(color), 1.0 / Gamma);

        outColor = float4(max(0.0, color), 1.0);
    }

    technique TimothyColorHDR
    <
        ui_label = "Sinitsa: FairyColors";
        ui_tooltip = "";
    >
    {
        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = PS_TimothyColorHDR;
        }
    }
}