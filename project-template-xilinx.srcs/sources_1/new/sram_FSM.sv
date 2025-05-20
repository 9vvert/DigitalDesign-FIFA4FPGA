module sram_IO (
    input  wire        clk,
    input  wire        rst_n,

    // 上层接口
    input  wire        req,            // 读写请求
    input  wire        wr,             // 1:写, 0:读
    input  wire [19:0] addr,           // 20位地址
    input  wire [31:0] din,            // 写入数据
    input  wire [3:0]  be_n,           // 字节使能，低有效
    output reg  [31:0] dout,           // 读出数据
    output reg         ack,            // 请求完成

    // SRAM接口
    inout  wire [31:0] base_ram_data,   // SRAM 数据
    output reg  [19:0] base_ram_addr,   // SRAM 地址
    output reg  [3: 0] base_ram_be_n,   // SRAM 字节使能，低有效
    output reg         base_ram_ce_n,   // SRAM 片选，低有效
    output reg         base_ram_oe_n,   // SRAM 读使能，低有效
    output reg         base_ram_we_n    // SRAM 写使能，低有效
);

    // 数据总线三态控制
    reg [31:0] data_out;
    reg        data_oe; // 输出使能

    assign base_ram_data = data_oe ? data_out : 32'bz;

    // 状态机
    localparam IDLE  = 2'd0,
               READ  = 2'd1,
               WRITE = 2'd2,
               DONE  = 2'd3;
    reg [1:0] state, state_next;

    always @(posedge clk) begin
        if (rst_n)begin
            state <= IDLE;
        end else begin
            state <= state_next;
        end
    end

    always @(*) begin
        // 默认值
        base_ram_ce_n  = 1'b1;
        base_ram_we_n  = 1'b1;
        base_ram_oe_n  = 1'b1;
        base_ram_addr  = addr;
        base_ram_be_n  = be_n;
        data_out       = din;
        data_oe        = 1'b0;
        ack            = 1'b0;
        state_next     = state;

        case (state)
        IDLE: begin
            if (req) begin
                if (wr) state_next = WRITE;
                else    state_next = READ;
            end
        end

        READ: begin
            base_ram_ce_n = 1'b0;
            base_ram_oe_n = 1'b0;
            base_ram_we_n = 1'b1;
            // 等待1周期采样数据
            state_next = DONE;
        end

        WRITE: begin
            base_ram_ce_n = 1'b0;
            base_ram_we_n = 1'b0;
            base_ram_oe_n = 1'b1;
            data_oe       = 1'b1;
            // 等待1周期写入
            state_next = DONE;
        end

        DONE: begin
            ack = 1'b1;
            state_next = IDLE;
        end

        default: state_next = IDLE;
        endcase
    end

    // 读数据采样
    always @(posedge clk) begin
        if (state == READ)
            dout <= base_ram_data;
    end

endmodule