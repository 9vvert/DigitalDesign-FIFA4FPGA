module sin_table_rom (
    input wire clk,
    input wire [3:0] speed,      // 0~8 (4bit)
    input wire [3:0] sin_rate,   // 0~12 (4bit)
    output reg [9:0] sin_val
);
    (* ram_style = "block" *)reg [9:0] sin_table [0:8][0:12];
    initial begin
        // speed=0
        sin_table[0][ 0]=10'd999 ; sin_table[0][ 1]=10'd999 ; sin_table[0][ 2]=10'd999 ; sin_table[0][ 3]=10'd999 ; sin_table[0][ 4]=10'd999 ;
        sin_table[0][ 5]=10'd999 ; sin_table[0][ 6]=10'd999 ; sin_table[0][ 7]=10'd999 ; sin_table[0][ 8]=10'd999 ; sin_table[0][ 9]=10'd999 ;
        sin_table[0][10]=10'd999 ; sin_table[0][11]=10'd999 ; sin_table[0][12]=10'd999 ;
        // speed=1
        sin_table[1][ 0]=10'd999 ;   sin_table[1][ 1]=10'd839; sin_table[1][ 2]=10'd419; sin_table[1][ 3]=10'd279; sin_table[1][ 4]=10'd209;
        sin_table[1][ 5]=10'd167; sin_table[1][ 6]=10'd139; sin_table[1][ 7]=10'd119; sin_table[1][ 8]=10'd104; sin_table[1][ 9]=10'd93;
        sin_table[1][10]=10'd83;  sin_table[1][11]=10'd76;  sin_table[1][12]=10'd69;
        // speed=2
        sin_table[2][ 0]=10'd999 ;   sin_table[2][ 1]=10'd419; sin_table[2][ 2]=10'd209; sin_table[2][ 3]=10'd139; sin_table[2][ 4]=10'd104;
        sin_table[2][ 5]=10'd83;  sin_table[2][ 6]=10'd69;  sin_table[2][ 7]=10'd59;  sin_table[2][ 8]=10'd52;  sin_table[2][ 9]=10'd46;
        sin_table[2][10]=10'd41;  sin_table[2][11]=10'd38;  sin_table[2][12]=10'd34;
        // speed=3
        sin_table[3][ 0]=10'd999 ;   sin_table[3][ 1]=10'd279; sin_table[3][ 2]=10'd139; sin_table[3][ 3]=10'd93;  sin_table[3][ 4]=10'd69;
        sin_table[3][ 5]=10'd55;  sin_table[3][ 6]=10'd46;  sin_table[3][ 7]=10'd39;  sin_table[3][ 8]=10'd34;  sin_table[3][ 9]=10'd31;
        sin_table[3][10]=10'd27;  sin_table[3][11]=10'd25;  sin_table[3][12]=10'd23;
        // speed=4
        sin_table[4][ 0]=10'd999 ;   sin_table[4][ 1]=10'd209; sin_table[4][ 2]=10'd104; sin_table[4][ 3]=10'd69;  sin_table[4][ 4]=10'd52;
        sin_table[4][ 5]=10'd41;  sin_table[4][ 6]=10'd34;  sin_table[4][ 7]=10'd29;  sin_table[4][ 8]=10'd26;  sin_table[4][ 9]=10'd23;
        sin_table[4][10]=10'd20;  sin_table[4][11]=10'd19;  sin_table[4][12]=10'd17;
        // speed=5
        sin_table[5][ 0]=10'd999 ;   sin_table[5][ 1]=10'd167; sin_table[5][ 2]=10'd83;  sin_table[5][ 3]=10'd55;  sin_table[5][ 4]=10'd41;
        sin_table[5][ 5]=10'd33;  sin_table[5][ 6]=10'd27;  sin_table[5][ 7]=10'd23;  sin_table[5][ 8]=10'd20;  sin_table[5][ 9]=10'd18;
        sin_table[5][10]=10'd16;  sin_table[5][11]=10'd15;  sin_table[5][12]=10'd13;
        // speed=6
        sin_table[6][ 0]=10'd999 ;   sin_table[6][ 1]=10'd139; sin_table[6][ 2]=10'd69;  sin_table[6][ 3]=10'd46;  sin_table[6][ 4]=10'd34;
        sin_table[6][ 5]=10'd27;  sin_table[6][ 6]=10'd23;  sin_table[6][ 7]=10'd19;  sin_table[6][ 8]=10'd17;  sin_table[6][ 9]=10'd15;
        sin_table[6][10]=10'd13;  sin_table[6][11]=10'd12;  sin_table[6][12]=10'd11;
        // speed=7
        sin_table[7][ 0]=10'd999 ;   sin_table[7][ 1]=10'd119; sin_table[7][ 2]=10'd59;  sin_table[7][ 3]=10'd39;  sin_table[7][ 4]=10'd29;
        sin_table[7][ 5]=10'd23;  sin_table[7][ 6]=10'd19;  sin_table[7][ 7]=10'd17;  sin_table[7][ 8]=10'd14;  sin_table[7][ 9]=10'd13;
        sin_table[7][10]=10'd11;  sin_table[7][11]=10'd10;  sin_table[7][12]=10'd9;
        // speed=8
        sin_table[8][ 0]=10'd999 ;   sin_table[8][ 1]=10'd104; sin_table[8][ 2]=10'd52;  sin_table[8][ 3]=10'd34;  sin_table[8][ 4]=10'd26;
        sin_table[8][ 5]=10'd20;  sin_table[8][ 6]=10'd17;  sin_table[8][ 7]=10'd14;  sin_table[8][ 8]=10'd13;  sin_table[8][ 9]=10'd11;
        sin_table[8][10]=10'd10;  sin_table[8][11]=10'd9;   sin_table[8][12]=10'd8;
    end

    always @(posedge clk)
        sin_val <= sin_table[speed][sin_rate];
endmodule