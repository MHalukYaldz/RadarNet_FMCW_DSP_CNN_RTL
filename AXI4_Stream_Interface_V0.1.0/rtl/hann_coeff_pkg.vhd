----------------------------------------------------------------------------------
--Engineer: Mustafa Haluk Yaldız
--Module Name: axis_transaction
--Target Devices: Pnyq-Z2 
--Tool Versions: Vivado 2025.2
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package hann_coeff_pkg is                               -- Diğer dosyalarda kullanılacak tip ve fonk bildirimi

    -- İşaretsiz, 15 kesir biti: 0.0=0, 0.5=16384, 1.0=32768
    subtype hann_coeff_t is unsigned(15 downto 0);      -- 16-bit unsigned tipine hann_coeff_t adı verildi
    
    -- index: 0...255
    function hann_coeff(                                -- Fonksiyonun giriş parametresi index, tipi 8-bit unsigned 0...255
        index : unsigned(7 downto 0)
    ) return hann_coeff_t;
    
end package hann_coeff_pkg;

package body hann_coeff_pkg is                          -- Pketin uygulama bölümü
    
    type quarter_table_t is                             -- Katsayı tablosunun tipi tanımlandı, dizi
        array (0 to 64) of integer range 0 to 16384;
    -- 256 noktalı periyodik hann katsayıları
    -- Katsayıları 2^15 ile ölçekleyip en yakın tam sayıya yuvarladım
    -- Sadece n=0...64 arasındaki 65 katsayı saklandı kalanlar farklı indekslerle okunarak ve 
    -- gereken bölgelerde okunanı 32768 den çıkararak elde ettim
    
    constant HANN_QUARTER : quarter_table_t := (
    0, 5, 20, 44, 79, 123, 177, 241,
    315, 398, 491, 593, 705, 827, 958, 1098,
    1247, 1406, 1573, 1749, 1935, 2128, 2331, 2542,
    2761, 2989, 3224, 3468, 3719, 3978, 4244, 4518,
    4799, 5087, 5381, 5682, 5990, 6304, 6624, 6950,
    7282, 7619, 7961, 8308, 8661, 9018, 9379, 9745,
    10114, 10487, 10864, 11245, 11628, 12014, 12403, 12794,
    13188, 13583, 13980, 14378, 14778, 15179, 15580, 15982,
    16384
    );
    
    function hann_coeff(                                -- Fonksiyonun uygulaması
        index : unsigned(7 downto 0)
    ) return hann_coeff_t is
        
        variable n     : integer range 0 to 255;
        variable value : integer range 0 to 32768;
        
    begin
        
        n := to_integer(index);
        
        if n <= 64  then                                -- 0-64 ü doğrudan tablodan okuma
            value := HANN_QUARTER(n);
            
        elsif n <= 128 then                             -- 65-128 için 128-n indeksindeki katsayıyı 32768'den çıkar
            value := 32768 - HANN_QUARTER(128 - n);
            
        elsif n <= 192 then                             -- 129-192 için n-128 indeksindeki katsayıyı 32768'den çıkar.
            value := 32768 - HANN_QUARTER(n - 128);
        
        else
            value := HANN_QUARTER(256 - n);             -- 193-255 için 256-n indeksindeki katsayıyı al
        end if;
        
        return to_unsigned(value, 16);                  -- integer değeri 16-bit unsigned a dönüştürme
        
    end function;
end package body hann_coeff_pkg;
