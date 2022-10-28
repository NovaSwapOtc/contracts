%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.access.ownable.library import Ownable

from openzeppelin.token.erc721.library import ERC721
from openzeppelin.introspection.erc165.library import ERC165


@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    name: felt, symbol: felt

){
    ERC721.initializer(name,symbol);
    // TODO : Ownable.initializer(owner);
    return ();
}

//GETTERS

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account: felt
) -> (
    balance : Uint256
){
    let (balance : Uint256) = ERC721.balance_of(account);
    return (balance=balance);
}

@view
func isApprovedForAll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt, operator : felt
) -> (isApproved : felt){
    let (isApproved : felt) = ERC721.is_approved_for_all(account, operator);
    return (isApproved=isApproved);
}

@view
func ownerOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id: Uint256
) -> (
    owner : felt
){
    let (res : felt) = ERC721.owner_of(token_id);
    return (owner=res);
}

//EXTERNAL

@external
func mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    to: felt, token_id: Uint256
) {
    // todo : add ownable Ownable.assert_only_owner()
    ERC721._mint(to, token_id);
    return ();
}


@external
func burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    id: Uint256
) {
    // todo : add ownable Ownable.assert_only_owner() 
    ERC721._burn(id);
    return ();
}

@external
func safeTransferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_: felt, to: felt, token_id: Uint256, data_len: felt, data: felt*
) {
    ERC721.safe_transfer_from(from_, to, token_id, data_len, data);
    return();
}

@external
func transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_: felt, to: felt, token_id: Uint256
) {
    ERC721.transfer_from(from_, to, token_id);
    return();
}

@external
func setApprovalForAll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator: felt, approved: felt
){
    ERC721.set_approval_for_all(operator, approved);
    return ();
}