// 和外层通信：填好wr和times的同时发送req请求，
module sram_IO(
    input clk,
    input rst,
    // 上层接口
    input req,            // 读写请求，在req为高的时候读取wr，
    input [19:0] times,     // 连续执行多少次操作，外界负责
    input wr,             // 1:写, 0:读， 外界必须保证和req同步变化
    input [19:0] addr,           // 20位地址        //需要及时更新
    input [31:0] din,            // 写入数据        //需要及时更新
    output [31:0] dout,           // 读出数据       //
    // SRAM接口
    inout  wire [31:0] base_ram_data,   // SRAM 数据
    output [19:0] base_ram_addr,   // SRAM 地址
    output reg  [3: 0] base_ram_be_n,   // SRAM 字节使能，低有效
    output reg         base_ram_ce_n,   // SRAM 片选，低有效
    output reg         base_ram_oe_n,   // SRAM 读使能，低有效
    output reg         base_ram_we_n    // SRAM 写使能，低有效
);
    // 外界通过 din来控制address 和 data(同一组不变)
    assign base_ram_data = (base_ram_we_n == 0) ? din : 32'bz;
    assign base_ram_addr = addr;
    assign dout = base_ram_data;            // 读取由外界负责，只在READ2读取
    localparam [2:0] IDLE=0, READ1=1, READ2=2, WRITE1=3, WRITE2=4, WRITE3=5;
    reg [2:0] sram_stat;
    reg [19:0] counter;     //执行特定的周期
    always@(posedge clk)begin
        base_ram_be_n <= 'd0;   //不使用字节使能
        if(rst)begin
            sram_stat <= IDLE;
            base_ram_ce_n <= 1'b1;
            base_ram_oe_n <= 1'b1;
            base_ram_we_n <= 1'b1;
            counter <= 0;
        end else begin
            case(sram_stat)
                IDLE: begin
                    if(req)begin
                        counter <= 0;
                        base_ram_ce_n <= 1'b0;  //选中
                        if(wr)begin     // 不要和具体的使能弄混淆，这里是高为1
                            base_ram_we_n <= 1'b1;
                            base_ram_oe_n <= 1'b1;
                            sram_stat <= WRITE1;
                        end else begin
                            base_ram_we_n <= 1'b1;
                            base_ram_oe_n <= 1'b0;      //读使能
                            sram_stat <= READ1;
                        end
                    end
                end
                READ1: begin    //保持
                    sram_stat <= READ2;
                end 
                READ2: begin    //准备切换下一轮的地址
                    if(counter == times - 1)begin
                        //结束
                        base_ram_oe_n <= 1'b1;
                        base_ram_ce_n <= 1'b1;
                        sram_stat <= IDLE;
                    end else begin
                        counter <= counter + 1;
                        sram_stat <= READ1;
                    end
                end
                WRITE1: begin
                    base_ram_we_n <= 1'b0;
                    sram_stat <= WRITE2;
                end
                WRITE2: begin
                    base_ram_we_n <= 1'b1;
                    sram_stat <= WRITE3;
                end
                WRITE3: begin
                    if(counter == times - 1)begin
                        base_ram_we_n <= 1'b1;
                        base_ram_ce_n <= 1'b1;      //拉高片选
                        sram_stat <= IDLE;
                    end else begin
                        sram_stat <= WRITE1;
                        counter <= counter + 1;
                    end
                end
            endcase
        end
    end

endmodule