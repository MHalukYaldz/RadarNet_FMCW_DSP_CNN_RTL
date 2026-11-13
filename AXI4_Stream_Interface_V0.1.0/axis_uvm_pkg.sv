`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Mustafa Haluk Yaldız
// Module Name: axis_transaction
// Target Devices: Pnyq-Z2 
// Tool Versions: Vivado 2025.2
//////////////////////////////////////////////////////////////////////////////////

`ifndef AXIS_TRANSACTION_SV                                 // Dosyanın aynı derleme biriminde tekrar dahil 
`define AXIS_TRANSACTION_SV                                 // edilmesini engeller

package axis_uvm_pkg;

import uvm_pkg::*;                                          // UVM sınıfları için kullanıyoruz
`include "uvm_macros.svh"                                   // UVM makrosunu getirir

class axis_transaction extends uvm_sequence_item;           // Sınıfı driver a gönderirken uvm işlem nesnesi yapar

    rand bit [31:0] data;                                   // Verimiz
    rand bit        last;                                   // Paket sonu bilgisi

    `uvm_object_utils_begin(axis_transaction)               // Sınıfı uvm factory e kaydeder
       `uvm_field_int(data, UVM_DEFAULT | UVM_HEX)
       `uvm_field_int(last, UVM_DEFAULT | UVM_BIN)
    `uvm_object_utils_end
    
    function new(input string name = "axis_transaction");   // Nesnesinin oluşturucusudur
        super.new(name);                                    // üst sınıfın oluşturucusunu çağırır
    endfunction
    
endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class axis_random_sequence extends uvm_sequence #(axis_transaction);
    
    `uvm_object_utils(axis_random_sequence)
    
    int unsigned word_count   = 100;
    int unsigned packet_words = 10;
    
    function new(input string name = "axis_random_sequence");
        super.new(name);
    endfunction
    
    task body();
        axis_transaction tr;
        
        if(word_count == 0 || packet_words == 0) begin
            `uvm_fatal("BAD_CONFIG", "Word ve paket uzunlugu sifir olamaz.")
        end
        
        for(int unsigned i = 0; i < word_count; i++) begin
            tr = axis_transaction::type_id::create($sformatf("tr_%0d", i));
            
            start_item(tr);
            
            // Sadece DATA yı random üret
            if(!tr.randomize(data)) begin
                `uvm_fatal("RAND_FAIL", "DATA randomization basarisiz")
            end
            
            // Her paketin son word ünü işaretli
            // Toplam sayı paket uzunluğuna bölünmese de son word açık kalan paketi tamamlasın
            tr.last = (((i+1) % packet_words) == 0) ||
                      (i == word_count -1);
            finish_item(tr);
        end
    endtask

endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class axis_ab_sequence extends uvm_sequence #(axis_transaction);    // Bu sequence axis_transaction türünde
                                                                    // nesneler üretir
    `uvm_object_utils(axis_ab_sequence)
    
    function new(input string name = "axis_ab_sequence");
        super.new(name);
    endfunction
    
    virtual task body();                                            // body() -> Sequence başlatıldığında yürütülen
        axis_transaction tr;                                        // işlemlerdir
        
        // İlk word: A Paket devam ediyor
        tr = axis_transaction::type_id::create("tr_a");
        
        start_item(tr);                                             // Nesneyi göndermek için sequencer dan izin al
        tr.data = 32'hAAAA_0001;                                    // Gönderilecek kelimenin içeriği
        tr.last = 1'b0;                                             // Gönderilecek kelimenin içeriği
        finish_item(tr);                                            // Nesneyi driver a gönderir ve driver ın 
                                                                    // tmamalandı bildirimi beklenir
        // İkinci word: B Paketin son kelimesi
        tr= axis_transaction::type_id::create("tr_b");
        
        start_item(tr);
        tr.data = 32'hBBBB_0002;
        tr.last = 1'b1;
        finish_item(tr);
    endtask

endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

typedef uvm_sequencer #(axis_transaction) axis_sequencer;

class axis_driver extends uvm_driver #(axis_transaction);

    `uvm_component_utils(axis_driver)
    
    virtual axis_uvm_if vif;                                        // Interface bağlantısı
    
    function new(
        input string name = "axis_driver",
        input uvm_component parent = null
    );
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        if (!uvm_config_db#(virtual axis_uvm_if)::get(              // Top tarafından paylaşılacak if bağlantısını al
            this, "", "vif", vif
        ))
            `uvm_fatal("NO_VIF", "Driver icin interface bulunamadi.")
    endfunction
    
    task run_phase(uvm_phase phase);
    
        // Kaynak başlangıçta veri sunmasın
        vif.s_axis_tdata = '0;
        vif.s_axis_tvalid = 1'b0;
        vif.s_axis_tlast = 1'b0;
        
        // İlk reset kalksın
        wait (vif.aresetn === 1'b1);
        
        forever begin
            // Sequence dan transaction alsın
            seq_item_port.get_next_item(req);                       // Sequencer dan sıradaki nesneyi alır;
                                                                    // req, uvm_driver sınıfından gelecek
            // Veriyi düşen kenarda girişe ver
            @(negedge vif.aclk);
            vif.s_axis_tdata = req.data;                            // Sequence in belirlediği değerler
            vif.s_axis_tlast = req.last;                            // Sequence in belirlediği değerler
            vif.s_axis_tvalid = 1'b1;
            
            // Kabul edilene kadar sinyaller değişmesin
            do begin
                @(posedge vif.aclk);
            end while (vif.s_axis_tready !== 1'b1);
            
            // Word kabul edildi; Kaynak valid i düşsün
            @(negedge vif.aclk);
            vif.s_axis_tvalid = 1'b0;
            vif.s_axis_tlast = 1'b0;
            
            // Sequence e bu işlemin tamamlandığını bildirsin
            seq_item_port.item_done();                              // Giriş aktarımının tmamlandığını sequence a
        end                                                         // bildirir; dest teslimi beklemiyor
    endtask
endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class axis_source_monitor extends uvm_monitor;

    `uvm_component_utils(axis_source_monitor)
    
    virtual axis_uvm_if vif;
    
    uvm_analysis_port #(axis_transaction) ap;
    
    function new(
        input string name = "axis_source_monitor",
        input uvm_component parent = null
    );
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        ap = new("ap", this);
        
        if(!uvm_config_db#(virtual axis_uvm_if)::get(
            this, "", "vif", vif
        )) begin
            `uvm_fatal("NO_VIF", "Source monitor interface bulunamadi");
           end
    endfunction
    
    task run_phase(uvm_phase phase);
        axis_transaction tr;
        
        forever begin
            @(posedge vif.aclk);
            
            if(vif.aresetn === 1'b1 &&
               vif.s_axis_tvalid === 1'b1 &&
               vif.s_axis_tready === 1'b1) begin
               
               // Transaction alanları bit türünde olduğu için X/Z bilgisini kaybetmeden önce kontrol
               if($isunknown({
                    vif.s_axis_tdata, vif.s_axis_tlast
               }))
                    `uvm_fatal(
                        "Input_X",
                        "Kabul edilen DATA veya LAST, X/Z içeriyor."
                     )
                     
               tr = axis_transaction::type_id::create("tr");
               
               tr.data = vif.s_axis_tdata;
               tr.last = vif.s_axis_tlast;
               
               `uvm_info(
                    "INPUT",
                    $sformatf(
                        "Kabul edildi: DATA = %08h LAST = %b",
                        tr.data, tr.last
                        ),
                        UVM_MEDIUM
                    )
                
                ap.write(tr);
            end
        end
    endtask
endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class axis_source_agent extends uvm_agent;                  // Driver-sequencer bağlantısını kur

    `uvm_component_utils(axis_source_agent)
    
    axis_sequencer sqr;                                     // Sequence in nesnelerini driver a iletir
    axis_driver drv;                                        // Nesneyi giriş sinyallerine uygular
    axis_source_monitor mon;                                // Giriş handshake ini gözlemler ve kabul edilen word gösterir
    
    function new(
        input string name = "axis_source_agent",
        input uvm_component parent = null
    );
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Monitor aktif ve pasif kullanımda
        mon = axis_source_monitor::type_id::create("mon", this);
        
        // Driver ve sequencer yalnız aktif agent ta bulunsun
        if(get_is_active() == UVM_ACTIVE) begin
            sqr = axis_sequencer::type_id::create("sqr", this);
            drv = axis_driver::type_id::create("drv", this);
        end
    endfunction
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        if(get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class axis_sink_driver extends uvm_component;

    `uvm_component_utils(axis_sink_driver)
    
    virtual axis_uvm_if vif;
    
    function new(
        input string name = "axis_sink_driver",
        input uvm_component parent = null
    );
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        if(!uvm_config_db#(virtual axis_uvm_if)::get(
            this, "", "vif", vif
        ))
            `uvm_fatal("NO_VIF", "Sink driver interface bulunamadi.")
    endfunction
    
//    task run_phase(uvm_phase phase);
//        vif.m_axis_tready = 1'b0;
        
//        forever begin
//            @(negedge vif.aclk);
            
//            if(vif.aresetn === 1'b1)
//                vif.m_axis_tready = 1'b1;
//            else
//                vif.m_axis_tready = 1'b0;
//        end
//    endtask
    task run_phase(uvm_phase phase);
        vif.m_axis_tready = 1'b0;
        
        wait(vif.aresetn === 1'b1);
        
        forever begin
            // çıkışta geçerli veriyi bekle
            do begin
                @(negedge vif.aclk);
            end while (vif.m_axis_tvalid !== 1'b1);
            
            // Ready=0 3 posedge de veri alınmasın
            //repeat(3)@(posedge vif.aclk);
            // Bekleme süresi rastgele olsun
            repeat($urandom_range(7,0))
                @(posedge vif.aclk);
            
            //Alıcı hazır
            @(negedge vif.aclk);
            vif.m_axis_tready = 1'b1;
            
            // Bu posedge de çıkış handshake i gerçekleşsin
            @(posedge vif.aclk);
            
            // Sonraki word ü bekletmek için ready düşsün
            @(negedge vif.aclk);
            vif.m_axis_tready = 1'b0;
        end
    endtask

endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class axis_sink_monitor extends uvm_monitor;

    bit          stalled_previous = 1'b0;
    logic [31:0] held_data;
    logic        held_last;
    
    int unsigned stalled_cycles = 0;
    
    `uvm_component_utils(axis_sink_monitor)
    
    virtual axis_uvm_if vif;
    
    uvm_analysis_port #(axis_transaction) ap;
    
    function new(
        input string name = "axis_sink_monitor",
        input uvm_component parent = null
    );
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        ap = new("ap", this);
        
        if(!uvm_config_db#(virtual axis_uvm_if)::get(
            this, "", "vif", vif
        ))
            `uvm_fatal("NO_VIF", "Sink monitor interface bulunamadi.")
    endfunction
    
//    task run_phase(uvm_phase phase);
//        axis_transaction tr;
        
//        forever begin
//            @(posedge vif.aclk);
            
//            if(vif.aresetn === 1'b1 &&
//               vif.m_axis_tvalid === 1'b1 &&
//               vif.m_axis_tready === 1'b1) begin
               
//               if($isunknown({
//                    vif.m_axis_tdata, vif.m_axis_tlast
//                }))
//                    `uvm_fatal(
//                        "OUTPUT_X",
//                        "Teslim edilen DATA veya LAST, X/Z iceriyor."
//                    )
                
//                tr = axis_transaction::type_id::create("tr");
                
//                tr.data = vif.m_axis_tdata;
//                tr.last = vif.m_axis_tlast;
                
//                `uvm_info(
//                    "OUTPUT",
//                    $sformatf(
//                        "Teslim edildi: DATA : %08h LAST : %b",
//                        tr.data, tr.last
//                    ),
//                    UVM_MEDIUM
//                )
                
//                ap.write(tr);
//            end
//        end
//    endtask

    task run_phase(uvm_phase phase);
        axis_transaction tr;
        
        forever begin
            @(posedge vif.aclk);
            
            if(vif.aresetn !== 1'b1) begin
                stalled_previous = 1'b0;
                held_data        = '0;
                held_last        = 1'b0;
                stalled_cycles   = 0;
            end
            else begin
                // Önceki kenarda veri bekliyorsa bu kenara kadar valid, data ve last korunmuş olmalı
                if(stalled_previous) begin
                    if(vif.m_axis_tvalid !== 1'b1 ||
                       vif.m_axis_tdata  !== held_data ||
                       vif.m_axis_tlast  !== held_last) begin
                            `uvm_error(
                                "BACKPRESSURE",
                                "Bekleme sirasinda VALID, DATA veya LAST degisti."
                            )
                    end
                end
                
                // Sadece teslim edilen word ü scb a gönder
                if(vif.m_axis_tvalid === 1'b1 &&
                   vif.m_axis_tready === 1'b1) begin
                        
                        if($isunknown({
                            vif.m_axis_tdata, vif.m_axis_tlast
                        })) begin
                            `uvm_fatal(
                                "OUTPUT_X",
                                "Teslim edilen DATA veya LAST, X/Z iceriyor."
                            )
                        end
                        
                        tr = axis_transaction::type_id::create("tr");
                        tr.data = vif.m_axis_tdata;
                        tr.last = vif.m_axis_tlast;
                        
                        `uvm_info(
                            "OUTPUT",
                            $sformatf(
                                "Teslim edildi: DATA=%08h LAST=%b",
                                tr.data, tr.last
                            ),
                            UVM_MEDIUM
                        )
                        
                        ap.write(tr);
                end
                
                // Sonraki posedge kontrolü hazırlama
                stalled_previous =
                    (vif.m_axis_tvalid === 1'b1 &&
                     vif.m_axis_tready === 1'b0);
                     
                if(stalled_previous)
                    stalled_cycles++;
                    
                held_data = vif.m_axis_tdata;
                held_last = vif.m_axis_tlast;
            end
        end
    endtask
endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class axis_sink_agent extends uvm_agent;

    `uvm_component_utils(axis_sink_agent)
    
    axis_sink_driver drv;
    axis_sink_monitor mon;
    
    function new(
        input string name = "axis_sink_agent",
        input uvm_component parent = null
    );
    super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        mon = axis_sink_monitor::type_id::create("mon", this);
        
        if(get_is_active() == UVM_ACTIVE)
            drv = axis_sink_driver::type_id::create("drv", this);
    endfunction
endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Giriş ve çıkış monitörleri için ayrı analysis girişleri
`uvm_analysis_imp_decl(_input)
`uvm_analysis_imp_decl(_output)

class axis_scoreboard extends uvm_scoreboard;
    
    `uvm_component_utils(axis_scoreboard)
    
    uvm_analysis_imp_input #(
        axis_transaction, axis_scoreboard
    ) input_imp;
    
    uvm_analysis_imp_output #(
        axis_transaction, axis_scoreboard
    ) output_imp;
    
    // Kabul edilen ama henüz teslim edilmeyen word ler
    axis_transaction expected_q[$];
    
    int unsigned input_count    = 0;
    int unsigned output_count   = 0;
    int unsigned matched_count  = 0;
    
    function new(
        input string name = "axis_scoreboard",
        input uvm_component parent = null
    );
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        input_imp = new("input_imp", this);
        output_imp = new("output_imp", this);
    endfunction
    
    // Source monitor tarafından yayınlanan word ü sakla
    function void write_input(axis_transaction tr);
        axis_transaction expected;
        
        expected = axis_transaction::type_id::create("expected");
        expected.copy(tr);
        
        expected_q.push_back(expected);
        input_count++;
    endfunction
    
    // Sink monitor tarafından yayınlanan word ü karşılaştır
    function void write_output(axis_transaction tr);
        axis_transaction expected;
        
        output_count++;
        
        if(expected_q.size() == 0) begin
            `uvm_error(
                "UNEXPECTED_OUTPUT",
                $sformatf(
                    "Beklenen veri yokken cikis geldi: DATA = %08h LAST = %b",
                    tr.data, tr.last
                )
            )
            return;
        end
        
        expected = expected_q.pop_front();
        
        if(tr.data !== expected.data ||
           tr.last !== expected.last) begin
           
           `uvm_error(
                "MISMATCH",
                $sformatf(
                    "Beklenen DATA=%08h LAST=%b, Gelen DATA=%08h LAST=%b",
                    expected.data, expected.last,
                    tr.data, tr.last
                )
            )
        end
        else begin
            matched_count++;

            `uvm_info(
                "MATCH",
                $sformatf(
                    "Eslesme: DATA=%08h LAST=%b",
                    tr.data, tr.last
                ),
                UVM_MEDIUM
            )
        end
    endfunction
    
    // Test sonunda teslim edilmemiş veri kaldı mı
    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        
        if (input_count == 0)
            `uvm_error(
                "NO_INPUT",
                "Test boyunca giris aktarimi olmadi."
            )

        if (expected_q.size() != 0)
            `uvm_error(
                "MISSING_OUTPUT",
                $sformatf(
                    "%0d kelime cikisa ulasmadi.",
                    expected_q.size()
                )
            )

        if (input_count != output_count)
            `uvm_error(
                "COUNT_ERROR",
                $sformatf(
                    "Giris sayisi=%0d, cikis sayisi=%0d",
                    input_count, output_count
                )
            )
    endfunction
    
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info(
            "SUMMARY",
            $sformatf(
                "Giris=%0d Cikis=%0d Eslesen=%0d Bekleyen=%0d",
                input_count, output_count,
                matched_count, expected_q.size()
            ),
            UVM_LOW
        )
    endfunction
endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class axis_env extends uvm_env;

    `uvm_component_utils(axis_env)
    
    axis_source_agent src_agent;
    axis_sink_agent   sink_agent;
    axis_scoreboard   scb;
    
    function new(
        input string name = "axis_env",
        input uvm_component parent = null
    );
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        src_agent = axis_source_agent::type_id::create(
            "src_agent", this
        );
        
        sink_agent = axis_sink_agent::type_id::create(
            "sink_agent", this
        );
        
        scb = axis_scoreboard::type_id::create(
            "scb", this
        );
    endfunction
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // DUT un kebul ettiği word ler
        src_agent.mon.ap.connect(scb.input_imp);
        
        // DUT un ilettiği word ler
        sink_agent.mon.ap.connect(scb.output_imp);
    endfunction
endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class axis_ab_test extends uvm_test;

    `uvm_component_utils(axis_ab_test)
    
    axis_env env;
    virtual axis_uvm_if vif;
    
    function new(
        input string name = "axis_ab_test",
        input uvm_component parent = null
    );
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        env = axis_env::type_id::create("env", this);
        
        if(!uvm_config_db#(virtual axis_uvm_if)::get(
            this, "", "vif", vif
        ))
            `uvm_fatal("NO_VIF", "Test interface bulumadi.")
    endfunction
    
    task run_phase(uvm_phase phase);
        axis_ab_sequence seq;
        
        phase.raise_objection(this);
        
        seq = axis_ab_sequence::type_id::create("seq");
        
        fork
            begin
                // Başlangıç resetinin kaldırılmasını bekle
                wait(vif.aresetn === 1'b1);
                
                // A ve B word lerini source sequencer a gönder
                seq.start(env.src_agent.sqr);                       // A/B sequence ını source agent ın sequencer ında çalıştır
                
                // Girişe kabulden sonra iki word ün çıkışa teslimini bekle
                wait(env.scb.output_count >= 2);                    // Word lerin çıkışa teslimini bekle
                
                // Fazladan aktarım var mı
                repeat(3) @(negedge vif.aclk);
                
                if(env.scb.input_count      !=2 ||
                   env.scb.output_count     !=2 ||
                   env.scb.matched_count    !=2)
                   `uvm_error(
                        "AB_RESULT",
                        "A/B testi beklenen iki eslesmeyle tamamlanmadi"
                    )
                
                if(env.sink_agent.mon.stalled_cycles < 6) begin
                    `uvm_error(
                        "STALL_COUNT",
                        "A ve B icin toplam en az 6 bekleme cevrimi gorulmedi."
                    )
                end
                
                `uvm_info(
                    "STALL_COUNT",
                    $sformatf(
                        "Gozlenen bekleme cevrimi=%0d",
                        env.sink_agent.mon.stalled_cycles
                    ),
                    UVM_LOW
                )
            end
            
            begin
                // Reset veya aktarım takılırsa testi durdur
                repeat(200) @(posedge vif.aclk);
                
                `uvm_fatal(
                    "TIMEOUT",
                    "A/B testi 200 saat cevriminde tamamlanamadi."
                )
            end
        join_any
        
        // Normal akış tamamlandıysa timeout sonlansın
        disable fork;
        
        phase.drop_objection(this);
    endtask
endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class axis_random_test extends axis_ab_test;

    `uvm_component_utils(axis_random_test)
    
    function new(
        input string name = "axis_random_test",
        input uvm_component parent = null
    );
        super.new(name, parent);
    endfunction
    
    task run_phase(uvm_phase phase);
        axis_random_sequence seq;
        
        phase.raise_objection(this);
        
        seq = axis_random_sequence::type_id::create("seq");
        seq.word_count   = 100;
        seq.packet_words = 10;
        
        fork
            begin
                wait(vif.aresetn === 1'b1);
                
                seq.start(env.src_agent.sqr);
                
                // Kaynağın bitmesi, tüm veriler çıkması değil
                wait(env.scb.output_count >= seq.word_count);
                
                // Fazladan teslim olursa monitör/scoreboard görsün
                repeat(3)@(negedge vif.aclk);
                
                if(env.scb.input_count   != seq.word_count ||
                   env.scb.output_count  != seq.word_count ||
                   env.scb.matched_count != seq.word_count) begin
                   
                   `uvm_error(
                        "RANDOM_RESULT",
                        $sformatf(
                            "Beklenen=%0d Giris=%0d Cikis=%0d Eslesen=%0d",
                            seq.word_count,
                            env.scb.input_count,
                            env.scb.output_count,
                            env.scb.matched_count
                        )
                   )
                end
                
                if(env.sink_agent.mon.stalled_cycles == 0) begin
                    `uvm_error(
                        "NO_STALL",
                        "Testte hic backpressure olusmadi."
                    )
                end
                
                `uvm_info(
                    "STALL_COUNT",
                    $sformatf(
                        "Gozlenen bekleme cevrimi =%0d",
                        env.sink_agent.mon.stalled_cycles
                    ),
                    UVM_LOW
                )
            end
            
            begin
                repeat(2000)@(posedge vif.aclk);
                
                `uvm_fatal(
                    "TIMEOUT",
                    "Rastgele test 2000 saat cevriminde tamamlanamadi."
                )
            end
        join_any
        
        disable fork;
        
        phase.drop_objection(this);
        
    endtask

endclass
endpackage
`endif
