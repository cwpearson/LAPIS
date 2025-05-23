//===- PartTensorOps.td - PartTensor dialect ops ------*- tablegen -*-===//
//
// The following operations bootstrap working with partition solely
// within the Linalg dialect. They provide temporary bridges between a
// future PartTensorType (now an opaque pointer), the actual TensorType,
// and MemRef arrays underlying an actual partition storage scheme in memory.
//
// Lacking a proper partition type, the 'partition' operation
// provides a bridge between an opaque pointer and a regular tensor type
// just to simplify feeding the value into a Linalg op. The operation
// simply disappears during lowering.
//
// The other operations form the bridge between the opaque pointer and
// the actual storage of pointers, indices, and values. These operations
// resemble 'buffer_cast' in the sense that they map tensors to
// their bufferized memrefs, but they lower into actual calls since
// partition storage does not bufferize into a single memrefs, as dense
// tensors do, but into a hierarchical storage scheme where pointers
// access memrefs with indices and eventually into values.
//
// TODO: introduce PartTensorType as first class citizen in MLIR
//
//===----------------------------------------------------------------------===//

#ifndef PARTTENSOR_OPS
#define PARTTENSOR_OPS

include "mlir/Dialect/Arith/IR/ArithBase.td"
include "PartTensorBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// Base class.
class PartTensor_Op<string mnemonic, list<Trait> traits = []>
    : Op<PartTensor_Dialect, mnemonic, traits>;

def PartTensor_GetPartitionsOp : PartTensor_Op<"get_partitions", [Pure]>,
                                Arguments<(ins AnyTensor
                                           : $primary)>,
                                Results<(outs AnyStridedMemRefOfRank<1>
                                         : $tuples)> {
  let summary = "get all the partition specs";
  let description = [{
     This operation will take a tensor and give all the indices of a tensor in a hyper-rectangular form where 
	 tuples will give the start and end indices of the the partition tensor from the tensor.
     Example:
     ```mlir
      !Partition = type !llvm.ptr<i8>
	  arg0 = tensor<?x?xf32, #sp, # part>

      %0 = part_tensor.get_partitions %arg0 : <?x?xf32, #ar1, #ar2> -> tensor<?xindex>
     ```
   }];
  let assemblyFormat =
      "$primary attr-dict `:` type($primary) `->` type($tuples)";
}
 def PartTensor_GetActiveMaskOp : PartTensor_Op<"get_active_mask">,
 	Arguments<(ins AnyTensor:$partTensor,
        AnyStridedMemRefOfRank<1>:$tupleList, Index:$dim)>,
	Results<(outs Index:$result)> {
		let summary = "get active mask for a given part tensor across given"
            "dimension";
		let description = [{
			This operation takes in parttensor (which has sparse tensor
            partitions), a partspec and a dimension and returns list of
            coordinates representing projection of sparse tensor on that
            dimension.
		}];
		// %active_mask = partition.get_active_mask(%part_tensor,
        //     %part_spec, %dim) -> memref<index>
		let assemblyFormat = "$partTensor `,` $tupleList attr-dict `,` $dim `:`"
            "type($partTensor) `,` type($tupleList) `->` type($result)";
		}
 def PartTensor_GetSliceOp : PartTensor_Op<"get_slice">,
 	Arguments<(ins AnyTensor:$Parts, AnyStridedMemRefOfRank<1>:$tupleList)>,
	Results<(outs AnyTensor:$result)> {
		let summary = "get slice";
		let description = [{
			This operation will take tuples and output one tensor
			}];
		//%slice = partition.get_slice(%total_iteration_space,%partition) -> tensor<2xindex>
		let assemblyFormat = " $Parts `,` $tupleList attr-dict `:` type($Parts) `,` type($tupleList) `->` type($result)";
        }
 def PartTensor_GetSliceForActiveMaskOp :
     PartTensor_Op<"get_slice_for_active_mask"> {
        let arguments = (ins AnyTensor:$Parts,
            AnyStridedMemRefOfRank<1>:$tupleList,
            Index:$activeMask,
            Index:$activeMaskDim
        );
        let results = (outs AnyTensor:$result);
		let summary = "get slice";
		let description = [{
			This operation will take tuples and output one tensor
		}];
		//%slice = partition.get_slice(%total_iteration_space,%partition) -> tensor<2xindex>
		let assemblyFormat = " $Parts `,` $tupleList `,` $activeMask `,` "
            "$activeMaskDim "
            "attr-dict `:` type($Parts) `,` type($tupleList)  `,` "
            "type($activeMask) `,` type($activeMaskDim) `->` type($result)";
		}
 def PartTensor_SetSliceOp : PartTensor_Op<"set_slice">,
     Arguments<(ins AnyTensor:$in_part_tensor, AnyStridedMemRefOfRank<1>:$part_spec, AnyTensor:$sparse_tensor)>,
     Results<(outs AnyTensor:$result_part_tensor)> {
         let summary = "set slice";
         let description = [{
             This operation will take tuples and output one tensor
             }]; 
         //%slice = partition.get_slice(%total_iteration_space,%partition) -> tensor<2xindex>
         // let assemblyFormat = " $in_part_tensor `,` $part_spec `,` $sparse_tensor attr-dict `:` type($in_part_tensor) `,` type($part_spec) `->` type($result_part_tensor)";
         let assemblyFormat = " $in_part_tensor `,` $part_spec `,` "
         " $sparse_tensor attr-dict `:` type($in_part_tensor) `,` "
         " type($part_spec) `,` type($sparse_tensor) `->` "
         " type($result_part_tensor)";
         }

def PartTensor_UpdateSliceOp : PartTensor_Op<"update_slice">,
  Arguments<(ins AnyTensor:$in_part_tensor,
    AnyStridedMemRefOfRank<1>:$part_spec, AnyTensor:$sparse_tensor,
    AtomicRMWKindAttr:$update_op)>,
  Results<(outs AnyTensor:$result_part_tensor)> {
    let summary = "update slice";
    let description = [{
        This operation will take tuples and output one tensor
    }];
    let assemblyFormat = [{
        $in_part_tensor `,` $part_spec `,` $sparse_tensor `,` $update_op
        attr-dict `:` type($in_part_tensor) `,` type($part_spec) `,`
        type($sparse_tensor) `->` type($result_part_tensor)
      }];
  }
 def PartTensor_UpdateSliceWithActiveMaskOp :
     PartTensor_Op<"update_slice_with_active_mask"> {
        let arguments = (ins AnyTensor:$partTensor,
            AnyTensor:$spTensor,
            AnyStridedMemRefOfRank<1>:$partSpec,
            Index:$activeMask,
            Index:$activeMaskDim
        );
		let summary = "update slice with active mask";
		let description = [{
			This op updates $parttensor with $spTensor
		}];
        let results = (outs AnyTensor:$result);
		let assemblyFormat = " $partTensor `,` $spTensor `,` $partSpec `,` "
            " $activeMask `,` $activeMaskDim "
            "attr-dict `:` type($partTensor)  `,` type ($spTensor) `,` "
            " type($partSpec)  `,` type($activeMask) `,` type($activeMaskDim)"
            " `->` type($result)";
		}

def PartTensor_GetNumPartitionsOp : PartTensor_Op<"get_num_partitions">,
	Arguments<(ins AnyTensor:$tensor)>,
	Results<(outs AnySignlessIntegerOrIndex:$res)> {
		let summary = "get the size of partition plan";
		let description = [{
			This operation will represent the dimention
			}];
		// %partitions_num = partition.num_partitions %A: tensor<?x?xf32> -> index
		let assemblyFormat = " $tensor  attr-dict `:` type($tensor) `->` type($res)";
		}

#endif // PARTTENSOR_OPS
