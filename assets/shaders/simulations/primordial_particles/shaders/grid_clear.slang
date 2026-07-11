[[vk::binding(0, 0)]] RWStructuredBuffer<uint> grid_heads;

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 id : SV_DispatchThreadID) {
    if (id.x < 16384u) grid_heads[id.x] = 0xffffffffu;
}
