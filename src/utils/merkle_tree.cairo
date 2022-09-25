%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2

// proof should look like: x, [near_top_tree, ..., near_x]
// if merkle_branch_len is 0, assert will fail
@external
func assert_merkle_proof{pedersen_ptr: HashBuiltin*}(
    merkle_root, x, merkle_branch_len, merkle_branch: felt*
) {
    if (merkle_branch_len == 0) {
        assert merkle_root = x;
        return ();
    } else {
        tempvar next_branch_size = merkle_branch_len - 1;
        let (new_x) = hash2{hash_ptr=pedersen_ptr}(x, merkle_branch[next_branch_size]);
        assert_merkle_proof(merkle_root, new_x, next_branch_size, merkle_branch);
        return ();
    }
}
