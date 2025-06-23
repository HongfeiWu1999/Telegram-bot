defmodule Database do

  # ------------------Province--------------------

  def create_province_database() do
    :dets.open_file(:province, type: :set)
  end

  def insert_province() do
    {:ok, table} = :dets.open_file(:province)
    {:ok, contents}= File.read("./resources/province.txt")
    provinces = String.split(contents,"\r\n")
    for province <- provinces do
      [h,t] = String.split(province,"\t")
      :dets.insert(table,{t,h})
      IO.puts("Introducing into database 'province': Key-> #{inspect t}, Values-> #{inspect h}")
    end
    IO.puts("Correct")
  end

  # ----------------Municipality-------------------

  def create_municipality_database() do
    :dets.open_file(:municipality, type: :set)
  end

  def insert_municipality() do
    {:ok, table} = :dets.open_file(:municipality)
    {:ok, contents}= File.read("./resources/municipality.txt")
    municipalities = String.split(contents,"\r\n")
    for municipality <- municipalities do
      [h,t] = String.split(municipality,"\t")
      :dets.insert(table,{t,h})
      IO.puts("Introducing into database 'municipality': Key-> #{inspect t}, Values-> #{inspect h}")
    end
    IO.puts("Correct")
  end

end

