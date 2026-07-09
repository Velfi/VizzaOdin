struct Vertex_Input {
	[[vk::location(0)]]
	float2 pos: POSITION0;
	[[vk::location(1)]]
	float4 color: COLOR0;
	[[vk::location(2)]]
	float2 texcoord: TEXCOORD0;
	[[vk::location(3)]]
	float glyph: TEXCOORD1;
	[[vk::location(4)]]
	float4 effect: TEXCOORD2;
	[[vk::location(5)]]
	float4 material: TEXCOORD3;
};

struct Vertex_Output {
	float4 position: SV_Position;
	[[vk::location(0)]]
	float4 color: COLOR0;
	[[vk::location(1)]]
	float2 texcoord: TEXCOORD0;
	[[vk::location(2)]]
	float glyph: TEXCOORD1;
	[[vk::location(3)]]
	float4 effect: TEXCOORD2;
	[[vk::location(4)]]
	float4 material: TEXCOORD3;
};

[shader("vertex")]
Vertex_Output main(Vertex_Input input) {
	Vertex_Output output;
	output.position = float4(input.pos, 0.0, 1.0);
	output.color = input.color;
	output.texcoord = input.texcoord;
	output.glyph = input.glyph;
	output.effect = input.effect;
	output.material = input.material;
	return output;
}
