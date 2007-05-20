class DummyNNTPServer < NNTPServer

  def groups
    {
      'comp.sys.sinclair' => Group.new('comp.sys.sinclair')
    }
  end
  
end

class Group
  attr_reader :name

  def initialize(name)
    @name = name
  end
end