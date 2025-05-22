///// 测试 Img 数据是否正确地加载
module test_load(
    input ui_clk,
    input ui_rst,
    // 与SDRAM交互的信号
    output reg[1:0] sdram_cmd,          //命令，  0无效，1读取，2写入
    output reg[29:0] operate_addr,      //地址
    input [63:0] read_data,
    input cmd_done,
    //
    input show_begin,
    output reg [31:0] debug_number
);
    reg [29:0] file;                     // 从 01, 02, 03, 04, 05, 考察这5个文件
    reg [31:0] show_counter;
    reg [3:0] show_stat;
    reg [29:0] file_offset;
    reg last_cmd_done;

    reg [63:0] show_data;
    always@(posedge ui_clk)begin
        if(ui_rst)begin
            show_counter <= 0;
            file <= 1;
            show_stat <= 0;
            file_offset <= 0;
        end else begin
            debug_number[31:24] <= file[7:0];
            debug_number[23:16] <= file_offset[7:0];
            if(show_stat == 0)begin
                sdram_cmd <= 2'd1;
                operate_addr <= 30'd(file*5120 + file_offset);
                if( ~last_cmd_done & cmd_done)begin
                    sdram_cmd <= 2'd0;
                    show_data <= read_data;
                    show_stat <= 1;
                    if(file_offset == 248)begin
                        file_offset <= 0;
                        file <= file + 1;
                    end else begin
                        file_offset <= file_offset + 8;
                    end
                end
            end else if(show_stat == 1)begin
                if(show_counter == 25000000)begin
                    debug_number[15:0] <= show_data[63:48];
                    show_counter <= show_counter + 1;
                end else if(show_counter == 50000000)begin
                    debug_number[15:0] <= show_data[47:32];
                    show_counter <= show_counter + 1;
                end else if(show_counter == 75000000)begin
                    debug_number[15:0] <= show_data[31:16];
                    show_counter <= show_counter + 1;
                end else if(show_counter == 100000000)begin
                    debug_number[15:0] <= show_data[15:0];
                    show_counter <= 0;
                    show_stat <= 0;
                end else begin
                    show_counter <= show_counter + 1;
                end 
            end
            last_cmd_done <= cmd_done;
        end
    end


endmodule