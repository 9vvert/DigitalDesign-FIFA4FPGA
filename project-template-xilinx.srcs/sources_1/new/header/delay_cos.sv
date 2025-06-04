module delay_cos_table_rom (
    input  wire        clk,
    input  wire [7:0]  ang,      // 0~17
    output reg  [9:0]  cos_val
);
    (* ram_style = "distributed" *)reg [9:0] COS_TABLE [0:17];

    initial begin
        // COS_TABLE
        COS_TABLE[ 0] = 10'd12;  COS_TABLE[ 1] = 10'd11;  COS_TABLE[ 2] = 10'd11;  COS_TABLE[ 3] = 10'd11;
        COS_TABLE[ 4] = 10'd11;  COS_TABLE[ 5] = 10'd10;  COS_TABLE[ 6] = 10'd10;  COS_TABLE[ 7] = 10'd9;
        COS_TABLE[ 8] = 10'd9;   COS_TABLE[ 9] = 10'd8;   COS_TABLE[10] = 10'd7;   COS_TABLE[11] = 10'd6;
        COS_TABLE[12] = 10'd6;   COS_TABLE[13] = 10'd5;   COS_TABLE[14] = 10'd4;   COS_TABLE[15] = 10'd3;
        COS_TABLE[16] = 10'd2;   COS_TABLE[17] = 10'd1;
    end

    always @(posedge clk) begin
        cos_val <= COS_TABLE[ang];
    end

endmodule