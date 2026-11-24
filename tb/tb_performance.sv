
`timescale 1ns/1ps

// Proyecto 4 - Pochoco Trader
// Testbench de rendimiento y trafico de memoria
// Serie: Meta 2022, 20000 ticks

module tb_proyecto_4;

  localparam string PROGRAMA = "sw/trade.hex";
  localparam string SERIE =
      "tb/series/practica_meta_2022.csv";

  localparam int PERIODO_NS = 100000;
  localparam int NTICKS = 20000;
  localparam int CAJA0 = 10000;
  localparam int COMISION = 5;
  localparam int SPI_NS = 9500;

  // Reloj de 25 MHz
  logic clk = 0;
  always #20 clk = ~clk;

  logic sclk = 0;
  logic mosi = 0;
  logic cs_n = 1;
  wire miso;

  // Diseno bajo prueba
  pochoco_soc #(
    .MemFile(PROGRAMA)
  ) dut (
    .i_Clk(clk),
    .o_LED(),
    .i_Switch(4'b0000),

    .o_Segment1_A(),
    .o_Segment1_B(),
    .o_Segment1_C(),
    .o_Segment1_D(),
    .o_Segment1_E(),
    .o_Segment1_F(),
    .o_Segment1_G(),

    .o_Segment2_A(),
    .o_Segment2_B(),
    .o_Segment2_C(),
    .o_Segment2_D(),
    .o_Segment2_E(),
    .o_Segment2_F(),
    .o_Segment2_G(),

    .i_SPI_SCLK(sclk),
    .i_SPI_MOSI(mosi),
    .i_SPI_CS_n(cs_n),
    .o_SPI_MISO(miso)
  );

  // --------------------------------------
  // Lectura de precios
  // --------------------------------------

  int precio [20000];

  task automatic leer_serie;
    int fd, t, r;
    string encabezado;

    fd = $fopen(SERIE, "r");

    if (fd == 0) begin
      $display("ERROR: no se encontro %s", SERIE);
      $finish;
    end

    r = $fgets(encabezado, fd);

    for (int n = 0; n < NTICKS; n++)
      r = $fscanf(fd, "%d,%d\n", t, precio[n]);

    $fclose(fd);
  endtask

  // --------------------------------------
  // Comunicacion SPI modo 0
  // --------------------------------------

  int bits_x = 0;

  task automatic spi(
    input logic [7:0] enviar,
    output logic [7:0] recibido
  );

    cs_n = 0;
    #1000;

    for (int b = 7; b >= 0; b--) begin
      mosi = enviar[b];

      #500;
      sclk = 1;

      if (miso !== 1'b0 &&
          miso !== 1'b1)
        bits_x++;

      recibido[b] = (miso === 1'b1);

      #500;
      sclk = 0;
    end

    #500;
    cs_n = 1;

  endtask

  // --------------------------------------
  // Contabilidad financiera
  // --------------------------------------

  int caja = CAJA0;
  int acciones = 0;
  int w = CAJA0;
  int peak = CAJA0;
  int max_dd = 0;
  int ordenes = 0;

  task automatic ejecutar(
    input logic [7:0] decision,
    input int p
  );

    int q = decision[5:0];

    case (decision[7:6])

      2'b01: begin
        // Compra
        if (q > (caja - COMISION) / p)
          q = (caja - COMISION) / p;

        if (q > 0) begin
          caja -= q * p + COMISION;
          acciones += q;
          ordenes++;
        end
      end

      2'b10: begin
        // Venta
        if (q > acciones)
          q = acciones;

        if (q > 0 &&
            caja + q * p >= COMISION) begin
          caja += q * p - COMISION;
          acciones -= q;
          ordenes++;
        end
      end

      default: ;
    endcase

    w = caja + acciones * p;

    if (w > peak)
      peak = w;

    if (peak - w > max_dd)
      max_dd = peak - w;

  endtask

  // --------------------------------------
  // Contadores de rendimiento
  // --------------------------------------

  int ciclos = 0;
  int peor_caso = 0;
  int respuestas = 0;
  int precios_perdidos = 0;

  int ic_tick = 0;
  int ic_max = 0;

  longint ciclos_total = 0;
  longint ic_total = 0;

  // Perfil por bloque Assembly
  longint ciclos_spi = 0;
  longint ciclos_finanzas = 0;
  longint ciclos_momentum = 0;
  longint ciclos_buffer = 0;
  longint ciclos_otros = 0;

  // Ciclos de espera
  longint ciclos_stall = 0;
  longint ciclos_rf_wait = 0;
  longint ciclos_lsu_busy = 0;

  // --------------------------------------
  // Contadores para roofline
  // --------------------------------------

  // Trafico logico del bus, no trafico
  // fisico interno de las memorias BRAM.

  longint bytes_instrucciones = 0;
  longint bytes_datos = 0;

  longint lecturas_datos = 0;
  longint escrituras_datos = 0;

  bit esperando = 0;

  // --------------------------------------
  // Monitoreo del procesador
  // --------------------------------------

  always @(posedge clk) begin

    ciclos++;

    if (dut.u_spi.byte_done) begin

      if (dut.u_spi.new_price_q)
        precios_perdidos++;

      ciclos = 0;
      ic_tick = 0;
      esperando = 1;

    end else if (esperando) begin

      // Lecturas de instrucciones
      // Cada solicitud: 4 bytes

      if (dut.u_core.instr_req_o)
        bytes_instrucciones += 4;

      // Accesos a RAM por bus de datos
      // Excluimos perifericos MMIO y SPI

      if (dut.u_core.data_req_o &&
          !dut.u_core.data_addr_o[31]) begin

        if (dut.u_core.data_we_o)
          escrituras_datos++;
        else
          lecturas_datos++;

        // Bus de datos de 32 bits
        bytes_datos += 4;

      end

      // Ciclos de espera
      if (dut.u_core.stall)
        ciclos_stall++;

      if (dut.u_core.instr_valid_id &&
          !dut.u_core.rf_ready)
        ciclos_rf_wait++;

      if (dut.u_core.lsu_busy)
        ciclos_lsu_busy++;

      // ----------------------------------
      // Clasificacion por bloque
      // ----------------------------------

      if (dut.u_core.pc_id >= 32'h03C &&
          dut.u_core.pc_id < 32'h04C)
        ciclos_spi++;

      else if (dut.u_core.pc_id >= 32'h04C &&
               dut.u_core.pc_id < 32'h0D4)
        ciclos_finanzas++;

      else if (dut.u_core.pc_id >= 32'h0D4 &&
               dut.u_core.pc_id < 32'h108)
        ciclos_momentum++;

      else if (dut.u_core.pc_id >= 32'h108 &&
               dut.u_core.pc_id < 32'h130)
        ciclos_buffer++;

      else
        ciclos_otros++;

      // Instrucciones completadas
      if (dut.u_core.u_id.commit)
        ic_tick++;

      // Detectar escritura de DECISION
      if (dut.u_spi.wr &&
          dut.u_spi.off == 2) begin

        if (ciclos > peor_caso)
          peor_caso = ciclos;

        if (ic_tick > ic_max)
          ic_max = ic_tick;

        ciclos_total += ciclos;
        ic_total += ic_tick;

        respuestas++;
        esperando = 0;

      end

    end

  end

  // --------------------------------------
  // Verificaciones
  // --------------------------------------

  int total_tests = 0;
  int tests_aprobados = 0;

  task automatic chequear(
    input bit ok,
    input string nombre
  );

    total_tests++;

    if (ok) begin
      tests_aprobados++;
      $display("PASS %s", nombre);
    end else begin
      $display("FAIL %s", nombre);
    end

  endtask

  // --------------------------------------
  // Simulacion principal
  // --------------------------------------

  logic [7:0] decision;

  int fd;
  int ref_q;
  int ref_w;
  int presupuesto;

  initial begin

    leer_serie();

    fd = $fopen("decisiones.csv", "w");

    $fdisplay(
      fd,
      "tick,precio,decision,caja,acciones,patrimonio"
    );

    #4000;

    for (int n = 0; n < NTICKS; n++) begin

      spi(precio[n], decision);

      ejecutar(decision, precio[n]);

      $fdisplay(
        fd,
        "%0d,%0d,%02h,%0d,%0d,%0d",
        n,
        precio[n],
        decision,
        caja,
        acciones,
        w
      );

      #(PERIODO_NS - SPI_NS);

    end

    $fclose(fd);

    // ----------------------------------
    // Referencia comprar y mantener
    // ----------------------------------

    ref_q =
      (CAJA0 - COMISION) / precio[0];

    ref_w =
      CAJA0 - COMISION
      - ref_q * precio[0]
      + ref_q * precio[NTICKS - 1];

    presupuesto =
      (PERIODO_NS - SPI_NS) / 40;

    // ----------------------------------
    // Resultados financieros
    // ----------------------------------

    $display(
      "Patrimonio final:          %0d", w
    );

    $display(
      "Ordenes ejecutadas:        %0d",
      ordenes
    );

    $display(
      "Perdida maxima:            %0d",
      max_dd
    );

    $display(
      "No operar:                 %0d",
      CAJA0
    );

    $display(
      "Comprar y mantener:        %0d",
      ref_w
    );

    $display(
      "Peor caso precio->decision: %0d ciclos (disponibles: %0d)",
      peor_caso,
      presupuesto
    );

    $display(
      "Detalle por tick en decisiones.csv"
    );

    // ----------------------------------
    // Testbench funcional
    // ----------------------------------

    chequear(
      bits_x == 0,
      "MISO sin valores X"
    );

    chequear(
      respuestas > 0,
      "el programa escribe DECISION"
    );

    chequear(
      precios_perdidos == 0,
      "el programa lee todos los precios"
    );

    chequear(
      peor_caso < presupuesto,
      "la decision llega antes del siguiente tick"
    );

    $display(
      "Testbenchs aprobados: %0d/%0d",
      tests_aprobados,
      total_tests
    );

    // ----------------------------------
    // Trafico logico de memoria
    // ----------------------------------

    if (respuestas > 0) begin

      $display(
        "\n=== TRAFICO LOGICO DE MEMORIA ==="
      );

      $display(
        "Bytes instrucciones/tick: %0f",
        real'(bytes_instrucciones) /
        respuestas
      );

      $display(
        "Bytes bus datos/tick:     %0f",
        real'(bytes_datos) /
        respuestas
      );

      $display(
        "Bytes bus totales/tick:   %0f",
        real'(bytes_instrucciones +
              bytes_datos) /
        respuestas
      );

      $display(
        "Lecturas RAM/tick:        %0f",
        real'(lecturas_datos) /
        respuestas
      );

      $display(
        "Escrituras RAM/tick:      %0f",
        real'(escrituras_datos) /
        respuestas
      );

    end

    // ----------------------------------
    // Rendimiento del procesador
    // ----------------------------------

    if (respuestas > 0 &&
        ic_total > 0) begin

      $display(
        "IC promedio:             %0f",
        real'(ic_total) / respuestas
      );

      $display(
        "IC maximo:               %0d",
        ic_max
      );

      $display(
        "Ciclos promedio:         %0f",
        real'(ciclos_total) / respuestas
      );

      $display(
        "CPI promedio medido:     %0f",
        real'(ciclos_total) / ic_total
      );

      $display(
        "Tiempo promedio (us):    %0f",
        real'(ciclos_total) /
        respuestas * 0.04
      );

      $display(
        "Tiempo maximo (us):      %0f",
        peor_caso * 0.04
      );

    end

    // ----------------------------------
    // Perfil de ciclos por bloque
    // ----------------------------------

    $display(
      "\n=== PERFIL DE CICLOS POR BLOQUE ==="
    );

    $display(
      "SPI promedio:        %0f",
      real'(ciclos_spi) / respuestas
    );

    $display(
      "Finanzas promedio:   %0f",
      real'(ciclos_finanzas) / respuestas
    );

    $display(
      "Momentum promedio:   %0f",
      real'(ciclos_momentum) / respuestas
    );

    $display(
      "Buffer promedio:     %0f",
      real'(ciclos_buffer) / respuestas
    );

    $display(
      "Otros promedio:      %0f",
      real'(ciclos_otros) / respuestas
    );

    // ----------------------------------
    // Ciclos de espera
    // ----------------------------------

    $display(
      "\n=== CICLOS DE ESPERA ==="
    );

    $display(
      "Stall promedio:    %0f",
      real'(ciclos_stall) / respuestas
    );

    $display(
      "RF wait promedio:  %0f",
      real'(ciclos_rf_wait) / respuestas
    );

    $display(
      "LSU busy promedio: %0f",
      real'(ciclos_lsu_busy) / respuestas
    );

    $finish;

  end

endmodule
