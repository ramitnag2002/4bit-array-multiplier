
module mult_array (
    input wire clk,
    input wire rst_n,
    input wire [3:0] a,
    input wire [3:0] b,
    output reg [7:0] p
);

    // Input registers
    reg [3:0] a_reg, b_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= 4'b0000;
            b_reg <= 4'b0000;
        end
        else begin
            a_reg <= a;
            b_reg <= b;
        end
    end

    // 16 AND gates for partial products
    wire [3:0] pp0, pp1, pp2, pp3;

    assign pp0 = a_reg & {4{b_reg[0]}};
    assign pp1 = a_reg & {4{b_reg[1]}};
    assign pp2 = a_reg & {4{b_reg[2]}};
    assign pp3 = a_reg & {4{b_reg[3]}};

    // Intermediate signals
    wire [3:0] r0, r1, r2;
    wire [3:0] s1, s2, s3;
    wire [4:0] c1, c2, c3;

    assign r0 = {1'b0, pp0[3:1]};

    assign c1[0] = 1'b0;
    assign c2[0] = 1'b0;
    assign c3[0] = 1'b0;

    // 12 full adders: 4 per row
    genvar j;

    generate
        for (j = 0; j < 4; j = j + 1) begin : ADDER_ARRAY

            // Row 1
            full_adder FA1 (
                .a(pp1[j]),
                .b(r0[j]),
                .cin(c1[j]),
                .sum(s1[j]),
                .cout(c1[j+1])
            );

            // Row 2
            full_adder FA2 (
                .a(pp2[j]),
                .b(r1[j]),
                .cin(c2[j]),
                .sum(s2[j]),
                .cout(c2[j+1])
            );

            // Row 3
            full_adder FA3 (
                .a(pp3[j]),
                .b(r2[j]),
                .cin(c3[j]),
                .sum(s3[j]),
                .cout(c3[j+1])
            );

        end
    endgenerate

    // Pass intermediate results to next row
    assign r1 = {c1[4], s1[3:1]};
    assign r2 = {c2[4], s2[3:1]};

    // Assemble final 8-bit product
    wire [7:0] product;

    assign product = {
        c3[4],
        s3[3:1],
        s3[0],
        s2[0],
        s1[0],
        pp0[0]
    };

    // Output register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            p <= 8'b00000000;
        else
            p <= product;
    end

endmodule

