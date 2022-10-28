%lang starknet

@external
func sum_func{syscall_ptr: felt*, range_check_ptr}(
    a: felt, b: felt
) -> (res : felt) {
    return (res=a + b);
}