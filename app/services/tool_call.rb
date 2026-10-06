# A tool call proposed by the model. It is a request, not permission:
# nothing runs when one is built, and its arguments are untrusted input.
ToolCall = Data.define(:name, :arguments)
