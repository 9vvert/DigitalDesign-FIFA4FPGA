`timescale 1ns/1ps

module mod12_tb;
    localparam HSIZE = 1280, HMAX = 1560, VSIZE = 720, VMAX = 750;
    reg clk=0;
    always #1 clk = ~clk;

    //基本
    reg [11:0]hdata = 0;
    reg [11:0]vdata = 0;
    always @ (posedge clk)
    begin
        if (hdata == (HMAX - 1))
            hdata <= 0;
        else
            hdata <= hdata + 1;
    end

    // vdata
    always @ (posedge clk)
    begin
        if (hdata == (HMAX - 1)) 
        begin
            if (vdata == (VMAX - 1))        // 当一行扫描完了才开始下一行
                vdata <= 0;
            else
                vdata <= vdata + 1;
        end
    end


    //预测
    logic [11:0] next_vdata;
    logic [11:0] next_hdata;
    always_comb begin
        // --- 1. 计算下下一个像素坐标 ---
        if (hdata < HSIZE - 2) begin
            next_hdata = hdata + 2;
            if(vdata < VSIZE)begin
                next_vdata = vdata;
            end else begin
                next_vdata = 0;
            end
        end else if(hdata == HMAX - 1)begin     //一行的最后，这种情况下，需要预测下一行的第二个像素
            next_hdata = 1;
            if(vdata < VSIZE - 1)begin
                next_vdata = vdata + 1;
            end else begin
                next_vdata = 0;
            end

        end else begin
            next_hdata = 0;
            if(vdata < VSIZE - 1)begin
                next_vdata = vdata + 1;
            end else begin
                next_vdata = 0;
            end
        end

    end

     //能否被12整除
    logic flag;
    logic [2:0] odd_counter;
    logic [2:0] even_counter;   
    always_comb begin
        odd_counter = next_vdata[1] + next_vdata[3] + next_vdata[5] + next_vdata[7] + next_vdata[9] + next_vdata[11];
        even_counter = next_vdata[0] + next_vdata[2] + next_vdata[4] + next_vdata[6] + next_vdata[8] + next_vdata[10];
        if(next_vdata[1:0] == 0)begin       // 首先必须能被4整除
            // 奇数和偶数位上的1个数之差必须是3的倍数，那么只剩下相等，3-0, 0-3的情况
            if( (odd_counter==even_counter) || (odd_counter==3&&even_counter==0) || (odd_counter==0&&even_counter==3))begin
                flag = 1;
            end else begin
                flag = 0;
            end
        end else begin
            flag = 0;
        end
    end
    reg [3:0] vdata_mod_12;     // 同时计算出行数mod12
    reg [11:0]last_next_vdata;    // 预测vdata的旧值
    always@(posedge clk)begin
        if(flag)begin
            vdata_mod_12 <= 0;      // next_vdata被12整除，那么将余数记为0
        end else begin
            if(next_vdata != last_next_vdata)begin
                vdata_mod_12 <= vdata_mod_12 + 1;
            end
        end
        last_next_vdata <= next_vdata;
    end
endmodule   
   