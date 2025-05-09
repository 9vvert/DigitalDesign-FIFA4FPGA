function [31:0] distance;   // 返回两个点之间的距离平方值
    input [11:0] x1;
    input [11:0] y1;
    input [11:0] x2;
    input [11:0] y2;
    begin
        distance = ((x1 > x2 ? (x1 - x2) : (x2 - x1)) ** 2) +
                   ((y1 > y2 ? (y1 - y2) : (y2 - y1)) ** 2);
    end
endfunction

function [1:0] compare_distance; // 返回 0: 等于 r, 1: 大于 r, 2: 小于 r
    input [11:0] x1;
    input [11:0] y1;
    input [11:0] x2;
    input [11:0] y2;
    input [11:0] r;
    reg [31:0] distance_squared;
    reg [31:0] radius_squared;
    begin
        distance_squared = (x1 > x2 ? (x1 - x2) : (x2 - x1)) * (x1 > x2 ? (x1 - x2) : (x2 - x1)) +
                           (y1 > y2 ? (y1 - y2) : (y2 - y1)) * (y1 > y2 ? (y1 - y2) : (y2 - y1));

        // 计算半径的平方
        radius_squared = r * r;

        // 比较距离平方和半径平方
        if (distance_squared == radius_squared) begin
            compare_distance = 2'b00; // 等于 r
        end else if (distance_squared > radius_squared) begin
            compare_distance = 2'b01; // 大于 r
        end else begin
            compare_distance = 2'b10; // 小于 r
        end
    end
endfunction