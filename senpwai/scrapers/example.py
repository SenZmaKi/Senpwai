def example_function(arg1, arg2=[]):
    arg2.append(arg1)
    print(arg2)

# First call
example_function(1)  # Output: [1]

# Second call
example_function(2)  # Output: [1, 2]
