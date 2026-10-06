# Application-controlled decision about whether a proposed tool may run.
# The model cannot influence this; names not listed here are denied.
class ToolPolicy
  DECISIONS = {
    "transfer_money" => :confirm
  }.freeze

  def self.decision_for(name)
    DECISIONS.fetch(name, :deny)
  end
end
