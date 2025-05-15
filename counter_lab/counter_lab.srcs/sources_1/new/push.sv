module Push (
    input wire CLK, 
    input wire RST, 
    input wire btn1,
    input wire clk_1m,
    input wire btn2,
    output reg [6:0] High, 
    output reg [6:0] Low 
    );
    reg [3:0] cnt_H;
    reg [3:0] cnt_L;


    always_ff @(posedge CLK or posedge RST) begin
        if(RST) begin
            cnt_H <= 0;
            cnt_L <= 0;
        end else begin
            if (cnt_L == 9) begin
                if(cnt_H == 5) begin
                    cnt_H <= 0;
                    cnt_L <= 0;
                end else begin
                    cnt_H <= cnt_H + 1;
                    cnt_L <= 0;
                end
            end else begin
                cnt_L <= cnt_L + 1;
            end
        end
    end

    Decoder u1 (
        .d (cnt_H),
        .seg (High)
    );

    Decoder u2 (
        .d (cnt_L),
        .seg (Low)
    );
endmodule