import mode, config from howl
import File from howl.fs

describe 'mode', ->
  after_each -> for name in pairs mode do mode.unregister name

  describe '.register(spec)', ->
    it 'raises an error if any of the mandatory inputs are missing', ->
      assert.raises 'name', -> mode.register {}
      assert.raises 'create', -> mode.register name: 'foo'

  it '.by_name(name) returns a mode instance with <name>, or nil if not existing', ->
    assert.is_nil mode.by_name 'blargh'

    mode.register name: 'shish', create: -> {}
    assert.is_not_nil mode.by_name('shish')

  describe '.for_file(file)', ->
    context 'when the file extension is registered with a mode', ->
      it 'returns an instance of that mode', ->
        mode.register name: 'ext', extensions: 'foo', create: -> {}
        file = File 'test.foo'
        assert.equal 'ext', mode.for_file(file).name

    context 'when the file paths matches a mode pattern', ->
      it 'returns an instance of that mode', ->
        mode.register name: 'pattern', patterns: 'match%w+$', create: -> {}
        file = File 'matchme'
        assert.equal 'pattern', mode.for_file(file).name

    context 'when no matching mode can be found', ->
      it 'returns an instance of the mode "default"', ->
        file = File 'test.blargh'
        assert.equal 'default', mode.for_file(file).name

  context 'mode creation', ->
    it 'modes are created by calling the modes create function, passing the name', ->
      create = spy.new -> {}
      mode.register name: 'callme', :create
      mode.by_name('callme')
      assert.spy(create).was_called_with 'callme'

  it 'mode instances are memoized', ->
    mode.register name: 'same', extensions: 'again', create: -> {}
    assert.equal mode.by_name('same'), mode.for_file File 'once.again'

  it 'mode instances automatically have their .name set', ->
    mode.register name: 'named', extensions: 'again', create: -> {}
    assert.equal mode.by_name('named').name, 'named'

  describe 'mode configuration variables', ->
    config.define name: 'mode_var', description: 'some var', default: 'def value'

    it 'mode instances automatically have their .config set', ->
      mode.register name: 'config', create: -> {}
      mode_config = mode.by_name('config').config
      assert.is_not_nil mode_config

      assert.equal 'def value', mode_config.mode_var
      mode_config.mode_var = 123
      assert.equal 123, mode_config.mode_var
      assert.equal 'def value', config.mode_var

    it 'the .config is pre-seeded with variables from the config option in mode registration (if any)', ->
      mode.register name: 'pre_config', config: { mode_var: 543 }, create: -> {}
      assert.equal 543, mode.by_name('pre_config').config.mode_var

    describe 'configure(mode_name, variables)', ->
      mode.register name: 'user_configured', create: -> {}

      it 'allows setting mode specific variables automatically upon creation', ->
        mode.configure 'user_configured', mode_var: 'from_user'
        assert.equal 'from_user', mode.by_name('user_configured').config.mode_var

      it 'automatically sets the config variables for any already instantiated mode', ->
        mode_config = mode.by_name('user_configured').config
        mode.configure 'user_configured', mode_var: 'after_the_fact'
        assert.equal 'after_the_fact', mode_config.mode_var

  describe 'mode inheritance', ->
    base = foo: 'foo'
    mode.register name: 'base', create: -> base
    mode.register name: 'sub', parent: 'base', create: -> {}

    it 'a mode extending another mode automatically delegates to that mode', ->
       assert.equal 'foo', mode.by_name('sub').foo

    it 'the instantiated mode has .parent set to the instantiated parent', ->
      assert.equal mode.by_name('base'), mode.by_name('sub').parent

    it 'an error is raised if the mode indicated by parent does not exist', ->
      assert.has_error ->
        mode.register name: 'wrong', parent: 'keyser_soze', create: -> {}
        mode.by_name 'wrong'

    it 'parent defaults to "default" unless given', ->
      mode.register name: 'orphan', create: -> {}
      assert.equal mode.by_name('default'), mode.by_name('orphan').parent

  describe '.unregister(name)', ->
    it '.unregister(name) removes the mode specified by <name>', ->
      mode.register name: 'mode', extensions: 'zen', create: -> {}
      mode.unregister 'mode'
      assert.is_nil mode.by_name 'mode'
      assert.equal mode.for_file(File('test.zen')), mode.by_name 'default'

    it 'removes any memoized instance', ->
      mode.register name: 'memo', extensions: 'memo', create: -> {}
      mode.unregister 'memo'
      live = mode.by_name 'memo'
      mode.register name: 'memo', extensions: 'memo', create: -> {}
      assert.is_not_equal live, mode.by_name('memo')

  it '.names contains all registered mode names', ->
    mode.register name: 'needle', create: -> {}
    names = [name for name in *mode.names when name == 'needle']
    assert.same names, { 'needle' }
