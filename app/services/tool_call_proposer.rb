# Turns a natural-language instruction into proposed ToolCalls using
# Claude's native tool calling. It sees only the instruction text and
# knows nothing about accounts, policy or execution. Everything it
# returns is untrusted, passed through exactly as the model produced it.
class ToolCallProposer
  MODEL = "claude-haiku-4-5"

  SYSTEM_PROMPT = <<~PROMPT
    You help a bank customer write transfer requests.
    When the customer asks to send money, call transfer_money.
    You cannot see accounts, balances or other customers.
    If the recipient or the amount is missing or unclear, ask a short question instead of calling the tool.
  PROMPT

  TRANSFER_MONEY_TOOL = {
    name: "transfer_money",
    description: "Propose sending money from the customer's own account to another person. " \
                 "This does not move money: the bank checks the proposal and asks the customer to confirm it. " \
                 "Use the recipient's name exactly as the customer wrote it. " \
                 "Give the amount in whole US cents, for example 1000 for $10.00.",
    strict: true,
    input_schema: {
      type: "object",
      properties: {
        recipient_name: { type: "string", description: "The recipient's name as the customer wrote it." },
        amount_cents: { type: "integer", description: "Amount in US cents, e.g. 1000 for $10.00." }
      },
      required: [ "recipient_name", "amount_cents" ],
      additionalProperties: false
    }
  }.freeze

  Proposal = Data.define(:tool_calls, :text, :raw_response)

  def initialize(send_request: method(:send_to_anthropic))
    @send_request = send_request
  end

  def call(instruction)
    parse(@send_request.call(request_params(instruction)))
  end

  private

  def request_params(instruction)
    {
      model: MODEL,
      max_tokens: 1024,
      system_: SYSTEM_PROMPT,
      tools: [ TRANSFER_MONEY_TOOL ],
      tool_choice: { type: "auto", disable_parallel_tool_use: true },
      messages: [ { role: "user", content: instruction } ]
    }
  end

  # raw is the response body as parsed JSON (string keys). A tool call is
  # only taken from a complete tool_use turn, never from a cut-off response.
  def parse(raw)
    blocks = raw.fetch("content", [])
    tool_calls =
      if raw["stop_reason"] == "tool_use"
        blocks.select { _1["type"] == "tool_use" }.map { ToolCall.new(name: _1["name"], arguments: _1["input"]) }
      else
        []
      end
    text = blocks.select { _1["type"] == "text" }.map { _1["text"] }.join("\n").presence

    Proposal.new(tool_calls:, text:, raw_response: raw)
  end

  # The SDK parses responses with symbol keys; a JSON round trip gives the
  # same string-keyed shape as the raw API body, without changing values.
  def send_to_anthropic(params)
    JSON.parse(Anthropic::Client.new.messages.create(**params).to_json)
  end
end
