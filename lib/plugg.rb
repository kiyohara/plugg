require 'plugg/version'
require 'active_support/core_ext'

module Plugg
  PLUGIN_CONFIG_FILENAME_DEFAULT = 'plugins.yml'

  attr_writer :plugin_config

  def plugins
    @plugins || []
  end

  def plugin_config
    @plugin_config ||= {}
  end

  def plugin_entries
    plugin_config['entries'] || []
  end

  def plugin_name_space
    ns = plugin_config['name_space']
    ns && ns.classify
  end

  #
  # plugin_config をファイルからロードする
  # yaml が渡される事を想定
  #
  def load_plugin_config_file(file)
    config = YAML.load_file(file)
    @plugin_config = config['plugin']
  end

  #
  # plugin_config に沿ってプラグインをロードする
  #
  def require_plugins(plugin_load_path = nil)
    plugin_entries.each do |plugin|
      # disable フラグ付きは require しない
      disable = plugin['disable'] || false
      next if disable

      plugin_name = plugin['name']
      next if plugin_name.nil?

      # version 指定がある場合はプラグイン名の末尾に追加する
      require_file = [plugin_name, plugin['version']].reject(&:nil?).join('_')

      # プラグイン名をファイルパスに変換する
      # Some::ExampleString -> some/example_string
      require_file = require_file.underscore

      if plugin_load_path
        require_path = Pathname("#{plugin_load_path}/#{require_file}")
      else
        require_path = require_file
      end

      begin
        require require_path
      rescue
        raise "cannot load plugin file -- #{require_path}"
      end

      # プラグインモジュールを内部のプラグインリストに登録
      register(plugin_name)
    end
  end

  #
  # config の読み込みと plugin の require を同時に実行する wrapper
  # config は plugin load path 配下にあるものとする
  # config 名はデフォルトを用いる
  #
  def load_plugins(plugin_load_path = nil)
    config_file_path = Pathname([
      plugin_load_path,
      PLUGIN_CONFIG_FILENAME_DEFAULT
    ].reject(&:nil?).join('/'))
    load_plugin_config_file(config_file_path)

    require_plugins(plugin_load_path)
  end

  #
  # プラグイン名からモジュールを取得する
  #
  def plugin_module(plugin_name)
    # プラグイン名をクラス名に変換する
    # some/example_string -> Some::ExampleString
    plugin_module_name = [
      plugin_name_space,
      plugin_name.classify
    ].reject(&:nil?).join('::')

    # クラス名からオブジェクトを取得する
    begin
      plugin_module_name.safe_constantize
    rescue
      raise "invalid plugin module -- #{plugin_module_name}"
    end
  end

  private

  #
  # プラグイン名からクラスを取得してプラグインリストに加える
  #
  def register(plugin_name)
    @plugins ||= []
    register_module = plugin_module(plugin_name)
    return unless register_module
    if @plugins.include?(register_module)
      fail "detect duplicate plugin register -- #{plugin_name}"
    else
      @plugins.push(register_module)
    end
  end
end

Dir[File.expand_path('../plugg', __FILE__) << '/*.rb'].each do |file|
  require file
end
