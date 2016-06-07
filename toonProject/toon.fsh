//グローバル変数
/*
 inputImageTextureという変数名はGPUImageで指定されている。
 GPUImage(OpenGL)側で初期化されテクスチャ情報がサンプリングされている。
 uniformはシステムから渡される定数であることを示す。
 sampler2Dは2Dのテクスチャをサンプリングするデータ型。uniformである必要がある。
 */
uniform sampler2D inputImageTexture;

/*
 textureCoordinateという変数名はGPUImageで指定されている。
 GPUImage(OpenGL)側で頂点シェーダにより座標値が書き込まれている。
 varyingは頂点シェーダで書き込まれていることを示す。
 highpは精度が高いことを示す。
 vec2は2Dベクトルを示す型。
 */
varying highp vec2 textureCoordinate;


uniform lowp float imageWidth;
uniform lowp float imageHeight;

uniform lowp float edge;
uniform lowp float edgeValue;

//エントリポイントmainはC言語とは違い戻り値は整数を返さない
void main() {
    
    highp vec4 color = texture2D(inputImageTexture, textureCoordinate).rgba;

    //highp float x_flag = 0.005;
    //highp float y_flag = 0.005;
    highp float x_flag = 1.0 / imageWidth;
    highp float y_flag = 1.0 / imageHeight;
    
    highp float px = textureCoordinate.x;
    highp float py = textureCoordinate.y;

    // ---
    // ガウスフィルタ
    highp vec3 destColor = color.rgb * 0.36;
    
    destColor += texture2D(inputImageTexture, vec2(px - x_flag, py - y_flag)).rgb * 0.04;
    destColor += texture2D(inputImageTexture, vec2(px         , py - y_flag)).rgb * 0.04;
    destColor += texture2D(inputImageTexture, vec2(px + x_flag, py - y_flag)).rgb * 0.04;
    destColor += texture2D(inputImageTexture, vec2(px - x_flag, py         )).rgb * 0.04;
    destColor += texture2D(inputImageTexture, vec2(px + x_flag, py         )).rgb * 0.04;
    destColor += texture2D(inputImageTexture, vec2(px - x_flag, py + y_flag)).rgb * 0.04;
    destColor += texture2D(inputImageTexture, vec2(px         , py + y_flag)).rgb * 0.04;
    destColor += texture2D(inputImageTexture, vec2(px + x_flag, py + y_flag)).rgb * 0.04;
    
    destColor += texture2D(inputImageTexture, vec2(px - (x_flag*2.0), py - (y_flag*2.0))).rgb * 0.02;
    destColor += texture2D(inputImageTexture, vec2(px - (x_flag*1.0), py - (y_flag*2.0))).rgb * 0.02;
    destColor += texture2D(inputImageTexture, vec2(px               , py - (y_flag*2.0))).rgb * 0.02;
    destColor += texture2D(inputImageTexture, vec2(px + (x_flag*1.0), py - (y_flag*2.0))).rgb * 0.02;
    destColor += texture2D(inputImageTexture, vec2(px + (x_flag*2.0), py - (y_flag*2.0))).rgb * 0.02;
    
    destColor += texture2D(inputImageTexture, vec2(px - (x_flag*2.0), py - y_flag)).rgb * 0.02;
    destColor += texture2D(inputImageTexture, vec2(px + (x_flag*2.0), py - y_flag)).rgb * 0.02;
    
    destColor += texture2D(inputImageTexture, vec2(px - (x_flag*2.0), py         )).rgb * 0.02;
    destColor += texture2D(inputImageTexture, vec2(px + (x_flag*2.0), py         )).rgb * 0.02;
    
    destColor += texture2D(inputImageTexture, vec2(px - (x_flag*2.0), py + y_flag)).rgb * 0.02;
    destColor += texture2D(inputImageTexture, vec2(px + (x_flag*2.0), py + y_flag)).rgb * 0.02;
    
    destColor += texture2D(inputImageTexture, vec2(px - (x_flag*2.0), py + (y_flag*2.0))).rgb * 0.02;
    destColor += texture2D(inputImageTexture, vec2(px - (x_flag*1.0), py + (y_flag*2.0))).rgb * 0.02;
    destColor += texture2D(inputImageTexture, vec2(px               , py + (y_flag*2.0))).rgb * 0.02;
    destColor += texture2D(inputImageTexture, vec2(px + (x_flag*1.0), py + (y_flag*2.0))).rgb * 0.02;
    destColor += texture2D(inputImageTexture, vec2(px + (x_flag*2.0), py + (y_flag*2.0))).rgb * 0.02;
    
    color = vec4(destColor.r, destColor.g, destColor.b, color.a);

    // ---
    // 輝度ベースのポスタライズ
    
    // 色合計
    highp float total_c = color.r + color.g + color.b;
    
    // 輝度の計算式
    // 0.299×R ＋ 0.587×G ＋ 0.114×B
    // 輝度算出
    highp float br = 0.299*color.r + 0.587*color.g + 0.114*color.b;
    
    
    if(total_c <= 0.0) {
        gl_FragColor = vec4(0, 0, 0, color.a);
        return;
    }
    if(br <= 0.0) {
        gl_FragColor = vec4(0, 0, 0, color.a);
        return;
    }
    
    // 輝度を丸める
    highp float unit = 1.0 / 255.0;
    highp float ret_br = 0.0;
    if(br < 0.0 * unit) { ret_br = 0.0 * unit; }
    else if(br < 48.0 * unit) { ret_br = 0.0 * unit; }
    else if(br < 92.0 * unit) { ret_br = 64.0 * unit; }
    else if(br < 192.0 * unit) { ret_br = 192.0 * unit; }
    else if(br < 236.0 * unit) { ret_br = 236.0 * unit; }
    else if(br < 256.0 * unit) { ret_br = 255.0 * unit; }

    // 変換結果の色合計 = 変換結果の輝度 * 元の色合計 / 元の輝度
    highp float ret_total_c = ret_br * total_c / br;
    
    // 色合計を各色に分解
    
    // 結果の色要素 = 元の色要素 * 結果の色合計 / 元の色合計
    highp float ret_r = color.r * ret_total_c / total_c;
    highp float ret_g = color.g * ret_total_c / total_c;
    highp float ret_b = color.b * ret_total_c / total_c;
    
    if(ret_r < 0.0) { ret_r = 0.0; }
    if(ret_g < 0.0) { ret_g = 0.0; }
    if(ret_b < 0.0) { ret_b = 0.0; }
    if(ret_r > 1.0) { ret_r = 1.0; }
    if(ret_g > 1.0) { ret_g = 1.0; }
    if(ret_b > 1.0) { ret_b = 1.0; }
    
    if (edge >= 1.0) {
        highp vec4 horizEdge = vec4( 0.0 );
        horizEdge -= texture2D( inputImageTexture, vec2( px - x_flag, py - y_flag ) ) * 1.0;
        horizEdge -= texture2D( inputImageTexture, vec2( px - x_flag, py          ) ) * 2.0;
        horizEdge -= texture2D( inputImageTexture, vec2( px - x_flag, py + y_flag ) ) * 1.0;
        horizEdge += texture2D( inputImageTexture, vec2( px + x_flag, py - y_flag ) ) * 1.0;
        horizEdge += texture2D( inputImageTexture, vec2( px + x_flag, py          ) ) * 2.0;
        horizEdge += texture2D( inputImageTexture, vec2( px + x_flag, py + y_flag ) ) * 1.0;
        highp vec4 vertEdge = vec4( 0.0 );
        vertEdge -= texture2D( inputImageTexture, vec2( px - x_flag, py - y_flag ) ) * 1.0;
        vertEdge -= texture2D( inputImageTexture, vec2( px         , py - y_flag ) ) * 2.0;
        vertEdge -= texture2D( inputImageTexture, vec2( px + x_flag, py - y_flag ) ) * 1.0;
        vertEdge += texture2D( inputImageTexture, vec2( px - x_flag, py + y_flag ) ) * 1.0;
        vertEdge += texture2D( inputImageTexture, vec2( px         , py + y_flag ) ) * 2.0;
        vertEdge += texture2D( inputImageTexture, vec2( px + x_flag, py + y_flag ) ) * 1.0;
        highp vec3 edge = sqrt((horizEdge.rgb * horizEdge.rgb) + (vertEdge.rgb * vertEdge.rgb));
        
        // 輝度算出
        highp float edge_br = 0.299*edge.r + 0.587*edge.g + 0.114*edge.b;
        
        if(edge_br > (255.0 - edgeValue) * unit) {
            gl_FragColor = vec4(0.3, 0.3, 0.3, color.a);
        }
        else {
            gl_FragColor = vec4(ret_r, ret_g, ret_b, color.a);
        }
    }
    else {
        gl_FragColor = vec4(ret_r, ret_g, ret_b, color.a);
    }
}