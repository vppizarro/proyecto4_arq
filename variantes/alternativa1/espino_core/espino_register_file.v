
module espino_register_file (
  input  wire        clk_i,
  input  wire        rst_ni,

  input  wire [3:0]  raddr_a_i,
  output wire [31:0] rdata_a_o,

  input  wire [3:0]  raddr_b_i,
  output wire [31:0] rdata_b_o,

  input  wire [3:0]  waddr_i,
  input  wire [31:0] wdata_i,
  input  wire        we_i
);

  // Banco RV32E: 16 registros de 32 bits
  reg [31:0] registers [0:15];

  // x0 siempre contiene cero
  assign rdata_a_o =
      (raddr_a_i == 4'd0)
      ? 32'd0
      : registers[raddr_a_i];

  assign rdata_b_o =
      (raddr_b_i == 4'd0)
      ? 32'd0
      : registers[raddr_b_i];

  // Escritura sincrona
  always @(posedge clk_i) begin
    if (we_i && waddr_i != 4'd0)
      registers[waddr_i] <= wdata_i;
  end

  // Sin reset sobre el arreglo, para
  // mantener una implementacion sintetizable.
  wire _unused = rst_ni;

endmodule
