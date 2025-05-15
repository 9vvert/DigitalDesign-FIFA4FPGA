module Counter (
    input wire CLK, 
    input wire RST, 
    input wire btn1,
    input wire clk_1m,
    input wire btn2,
    output reg [6:0] High, 
    output reg [6:0] Low 
    );
    reg [3:0] cnt_H2;
    reg [3:0] cnt_L2;
    reg [31:0] counter;

    wire [3:0] ulti_H =  cnt_H2;
    wire [3:0] ulti_L =  cnt_L2;

    always @(posedge CLK) begin
        if(RST) begin
            cnt_H2 <= 0;
            cnt_L2 <= 0;
            counter <= 32'd0;
        end else begin
            if(counter == 32'd999999) begin
                counter <= 32'd0;
                if (cnt_L2 == 9) begin
                    if(cnt_H2 == 5) begin
                        cnt_H2 <= 0;
                        cnt_L2 <= 0;
                    end else begin
                        cnt_H2 <= cnt_H2 + 1;
                        cnt_L2 <= 0;
                    end
                end else begin
                    cnt_L2 <= cnt_L2 + 1;
                end
            end else begin
                if(btn2)begin
                    counter <= counter + 32'd1;
                end
            end
        end
    end

    Decoder u1 (
        .d (ulti_H),
        .seg (High)
    );

    Decoder u2 (
        .d (ulti_L),
        .seg (Low)
    );
endmodule