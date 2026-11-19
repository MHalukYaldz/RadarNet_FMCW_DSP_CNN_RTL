----------------------------------------------------------------------------------
--Engineer: Mustafa Haluk Yaldız
--Module Name: axis_transaction
--Target Devices: Pnyq-Z2 
--Tool Versions: Vivado 2025.2
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.hann_coeff_pkg.all;

entity range_window is
    port(
        aclk            : in    STD_LOGIC;
        aresetn         : in    STD_LOGIC;

        s_axis_tdata    : in    STD_LOGIC_VECTOR(31 downto 0);
        s_axis_tvalid   : in    STD_LOGIC;
        s_axis_tready   : out    STD_LOGIC;
        s_axis_tlast    : in   STD_LOGIC;

        m_axis_tdata    : out   STD_LOGIC_VECTOR(31 downto 0);
        m_axis_tvalid   : out   STD_LOGIC;
        m_axis_tready   : in    STD_LOGIC;
        m_axis_tlast    : out   STD_LOGIC
    );
end entity range_window;

architecture RTL of range_window is

    signal sample_index : UNSIGNED(7 downto 0);         -- Kabul edilen örnekleri sayar
    signal coefficient  : hann_coeff_t;                 -- İndekse karşılık gelen 16-bit unsigned hann katsayısı
    
    signal data_reg     : STD_LOGIC_VECTOR(31 downto 0);-- İşlenmiş I/Q 
    signal valid_reg    : STD_LOGIC;
    signal last_reg     : STD_LOGIC;
    signal ready_int    : STD_LOGIC;
    
    subtype sample_t is signed(15 downto 0);			-- I veya Q için 16-bit signed tip
    subtype product_t is signed(32 downto 0);			-- Çarpım sonucu için 33-bit signed tip
    
    -- Çarpımın 15 kesir bitini kaldır en yakın tamsayıya yuvarla
    -- Tam yarım değerler sıfırdan uzağa
    function round_product(								-- Gerçek değerin 32768 katı old için; ölçek kaldırma
        product : product_t								-- 33-bit çarpımı, yuvarlanmış 16-bit örneği döndürme
    ) return sample_t is
        
        variable magnitude : unsigned(32 downto 0);		-- Çarpımın 33-bit işaretsiz büyüklüğü
        variable rounded   : product_t;					-- Yuvarlanmış sonucu, işaretiyle tut
        
    begin												-- Herşey pozitif olsun
        if product < 0 then
            magnitude := unsigned(-product);
        else
            magnitude := unsigned(product);
        end if;
        
        magnitude := magnitude + to_unsigned(16384, 33);-- Yarım ölçek ekleme
        rounded   := signed(shift_right(magnitude, 15));-- 15-bit sağa -> 32768 e böl
        
        if product < 0 then								-- İşareti geri koy
            rounded := -rounded;
        end if;
        
        return resize(rounded, 16);						-- Sonuç 16-bit signed değere döner
    end function;
    
    begin
        -- Mevcut örnek indeksine karşılık gelen katsayıyı üret; eş-zamanlı!
        coefficient <= hann_coeff(sample_index);
        
        -- Çıkış boşsa veya mevcut veri teslim edilecekse yeni veri alınabilir
		-- Reset aktif değilse, çıkışta veri yoksa veya veri bekleniyorsa çıkış hazırdır
        ready_int <= aresetn AND ((NOT valid_reg) OR m_axis_tready);
        
        s_axis_tready <= ready_int;
        
        m_axis_tdata  <= data_reg;
        m_axis_tvalid <= valid_reg;
        m_axis_tlast  <= last_reg;
        
        process(aclk)
            variable i_sample       : sample_t;			-- Girişten ayrılan I için geçici değişken
            variable q_sample       : sample_t;			-- Girişten ayrılan Q için geçici değişken
            variable coeff_signed   : signed(16 downto 0);-- Katsayının 17-bit signed biçimi
            variable i_product      : product_t;		-- I çarpımının 33-bit sonucu
            variable q_product      : product_t;		-- Q çarpımının 33-bit sonucu
            
        begin
            if(rising_edge(aclk)) then
            
                --Aktif low, senkron reset
                if aresetn = '0' then
                    sample_index <= (others => '0');	-- Sonraki chirp için indeks sıfırlanır
                    data_reg     <= (others => '0');
                    valid_reg    <= '0';
                    last_reg     <= '0';
                elsif ready_int = '1' then				-- Reset yoksa ve çıkış register ı yeni durumu alabiliyorsa
                    valid_reg <= s_axis_tvalid;
                    
                    if s_axis_tvalid = '1' then			-- Giriş handshake i
                        
                        i_sample := signed(s_axis_tdata(15 downto 0));
                        q_sample := signed(s_axis_tdata(31 downto 16));
                        
                        -- Katsayı pozitif; signed tip dönüşüm
                        coeff_signed := signed('0' & coefficient);
                        
                        i_product := i_sample * coeff_signed;
                        q_product := q_sample * coeff_signed;
                        
                        data_reg <= 
                            STD_LOGIC_VECTOR(round_product(q_product)) &
                            STD_LOGIC_VECTOR(round_product(i_product));
                            
                        last_reg <= s_axis_tlast;
                        
                        -- İşlediğimiz örnek indeks 255 yani 256. örnek mi
                        if sample_index = to_unsigned(255, 8) then
                            sample_index <= (others => '0');
                        else
                            sample_index <= sample_index + 1;
                        end if;
                end if;
            end if;
        end if;
    end process;
end architecture RTL;
