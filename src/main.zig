const std = @import("std");
const tensor = @import("tensor");
//--- layers
const layer = @import("layer");
const DenseLayer = layer.DenseLayer;
const ConvolutionalLayer = layer.ConvolutionalLayer;
const FlattenLayer = layer.FlattenLayer;
const PoolingLayer = layer.PoolingLayer;
const PoolingType = layer.poolingLayer.PoolingType;
const ActivationLayer = layer.ActivationLayer;
//--- other
const Model = @import("model").Model;
const loader = @import("dataloader");
const ActivationType = @import("activation_function").ActivationType;
const LossType = @import("loss").LossType;
const Trainer = @import("trainer");
const BatchNormLayer = @import("batchNormLayer").BatchNormLayer;
const onnx = @import("onnx/onnx.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var model1 = try onnx.parseFromFile(allocator, "/home/mirko/Documents/zig/Tiny/TheTinyBook/datasets/models/mnist-8/mnist-8.onnx");
    defer model1.deinit(allocator);

    //onnx.printStructure(&model1);

}
