module Find
  EVERYTHING_GLOB = '{,.[^.],..[^]}*' # everything but . and ..
  RECURSIVE_EVERYTHING_GLOB = File.join(EVERYTHING_GLOB+EVERYTHING_GLOB, EVERYTHING_GLOB)

  def excutables(path, glob = %w[** *])
    find(path) { |x| File.executable?(x) && !File.directory?(x) }
  end

  def dirs(path, glob = %w[** *])
    find(path) { |x| File.directory? x }
  end

  def files(path, glob = %w[** *])
    find(path) { |x| File.file?(x) && !File.directory?(x) }
  end

  # recursive find of all non . files
  def find(path, glob = %w[** *], &_block)
    path = normalize_path(path)
    result = Dir[File.join(path, *glob)]
    if block_given?
      result.select(&_block) 
    else
      result
    end
  end

  # recursive find of every file
  def find_all(path, &_block)
    find(path, RECURSIVE_EVERYTHING_GLOB, &_block)
  end
end
