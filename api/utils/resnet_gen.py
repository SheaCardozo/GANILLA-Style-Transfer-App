import torch
import torch.nn as nn

import torch.nn.functional as F

import sys


def resnet18(input_nc, output_nc, ngf, fpn_weights, use_dropout, **kwargs):
    model = ResNet(input_nc, output_nc, ngf, fpn_weights, BasicBlock_Ganilla, [2, 2, 2, 2], use_dropout, **kwargs)

    return model


class ResNet(nn.Module):

    def __init__(self, input_nc, output_nc, ngf, fpn_weights, block, layers, use_dropout):
        self.inplanes = ngf
        super(ResNet, self).__init__()

        # first conv
        self.pad1 = nn.ReflectionPad2d(input_nc)
        self.conv1 = nn.Conv2d(input_nc, ngf, kernel_size=7, stride=1, padding=0, bias=True)
        self.in1 = nn.InstanceNorm2d(ngf)
        self.relu = nn.ReLU(inplace=True)
        self.pad2 = nn.ReflectionPad2d(1)
        self.maxpool = nn.MaxPool2d(kernel_size=3, stride=2, padding=0)

        # Output layer
        self.pad3 = nn.ReflectionPad2d(output_nc)
        self.conv2 = nn.Conv2d(64, output_nc, 7)
        self.tanh = nn.Tanh()

        if block == BasicBlock_orj:
            # residuals
            self.layer1 = self._make_layer(block, 64, layers[0])
            self.layer2 = self._make_layer(block, 128, layers[1], stride=2)
            self.layer3 = self._make_layer(block, 128, layers[2], stride=2)
            self.layer4 = self._make_layer(block, 256, layers[3], stride=2)

            fpn_sizes = [self.layer1[layers[0] - 1].conv2.out_channels,
                         self.layer2[layers[1] - 1].conv2.out_channels,
                         self.layer3[layers[2] - 1].conv2.out_channels,
                         self.layer4[layers[3] - 1].conv2.out_channels]

        elif block == BasicBlock_Ganilla:
            # residuals
            self.layer1 = self._make_layer_ganilla(block, 64, layers[0], use_dropout, stride=1)
            self.layer2 = self._make_layer_ganilla(block, 128, layers[1], use_dropout, stride=2)
            self.layer3 = self._make_layer_ganilla(block, 128, layers[2], use_dropout, stride=2)
            self.layer4 = self._make_layer_ganilla(block, 256, layers[3], use_dropout, stride=2)

            fpn_sizes = [self.layer1[layers[0] - 1].conv2.out_channels,
                         self.layer2[layers[1] - 1].conv2.out_channels,
                         self.layer3[layers[2] - 1].conv2.out_channels,
                         self.layer4[layers[3] - 1].conv2.out_channels]

        else:
            print("Block Type is not Correct")
            sys.exit()

        self.fpn = PyramidFeatures(fpn_sizes[0], fpn_sizes[1], fpn_sizes[2], fpn_sizes[3], fpn_weights)

        # for m in self.modules():
        #    if isinstance(m, nn.Conv2d):
        #        n = m.kernel_size[0] * m.kernel_size[1] * m.out_channels
        #        m.weight.data.normal_(0, math.sqrt(2. / n))
        #    elif isinstance(m, nn.BatchNorm2d):
        #        m.weight.data.fill_(1)
        #        m.bias.data.zero_()

        # self.freeze_bn()

    def _make_layer(self, block, planes, blocks, stride=1):
        downsample = None
        if stride != 1 or self.inplanes != planes * block.expansion:
            downsample = nn.Sequential(
                nn.Conv2d(self.inplanes, planes * block.expansion,
                          kernel_size=1, stride=stride, bias=True),
                nn.BatchNorm2d(planes * block.expansion),
            )

        layers = []
        layers.append(block(self.inplanes, planes, stride, downsample))
        self.inplanes = planes * block.expansion
        for i in range(1, blocks):
            layers.append(block(self.inplanes, planes))

        return nn.Sequential(*layers)

    def _make_layer_ganilla(self, block, planes, blocks, use_dropout, stride=1):
        strides = [stride] + [1] * (blocks - 1)
        layers = []
        for stride in strides:
            layers.append(block(self.inplanes, planes, use_dropout, stride))
            self.inplanes = planes * block.expansion
        return nn.Sequential(*layers)

    def freeze_bn(self):
        '''Freeze BatchNorm layers.'''
        for layer in self.modules():
            if isinstance(layer, nn.BatchNorm2d):
                layer.eval()

    def forward(self, inputs):

        img_batch = inputs

        x = self.pad1(img_batch)
        x = self.conv1(x)
        x = self.in1(x)
        x = self.relu(x)
        x = self.pad2(x)
        x = self.maxpool(x)

        x1 = self.layer1(x)
        x2 = self.layer2(x1)
        x3 = self.layer3(x2)
        x4 = self.layer4(x3)

        out = self.fpn([x1, x2, x3, x4])  # use all resnet layers

        out = self.pad3(out)
        out = self.conv2(out)
        out = self.tanh(out)

        return out


class BasicBlock_orj(nn.Module):
    expansion = 1

    def __init__(self, inplanes, planes, stride=1, downsample=None):
        super(BasicBlock_orj, self).__init__()
        self.rp1 = nn.ReflectionPad2d(1)
        self.conv1 = conv3x3(inplanes, planes, stride)
        self.in1 = nn.InstanceNorm2d(planes)
        self.relu = nn.ReLU(inplace=True)
        self.rp2 = nn.ReflectionPad2d(1)
        self.conv2 = conv3x3(planes, planes)
        self.in2 = nn.InstanceNorm2d(planes)
        self.downsample = downsample
        self.stride = stride

    def forward(self, x):
        residual = x

        out = self.rp1(x)
        out = self.conv1(out)
        out = self.in1(out)
        out = self.relu(out)

        out = self.rp2(out)
        out = self.conv2(out)
        out = self.in2(out)

        if self.downsample is not None:
            residual = self.downsample(x)

        out += residual
        out = self.relu(out)

        return out


class BasicBlock_Ganilla(nn.Module):
    expansion = 1

    def __init__(self, in_planes, planes, use_dropout, stride=1):
        super(BasicBlock_Ganilla, self).__init__()
        self.rp1 = nn.ReflectionPad2d(1)
        self.conv1 = nn.Conv2d(in_planes, planes, kernel_size=3, stride=stride, padding=0, bias=False)
        self.bn1 = nn.InstanceNorm2d(planes)
        self.use_dropout = use_dropout
        if use_dropout:
            self.dropout = nn.Dropout(0.5)
        self.rp2 = nn.ReflectionPad2d(1)
        self.conv2 = nn.Conv2d(planes, planes, kernel_size=3, stride=1, padding=0, bias=False)
        self.bn2 = nn.InstanceNorm2d(planes)
        self.out_planes = planes

        self.shortcut = nn.Sequential()
        if stride != 1 or in_planes != self.expansion * planes:
            self.shortcut = nn.Sequential(
                nn.Conv2d(in_planes, self.expansion * planes, kernel_size=1, stride=stride, bias=False),
                nn.InstanceNorm2d(self.expansion * planes)
            )

            self.final_conv = nn.Sequential(
                nn.ReflectionPad2d(1),
                nn.Conv2d(self.expansion * planes * 2, self.expansion * planes, kernel_size=3, stride=1,
                          padding=0, bias=False),
                nn.InstanceNorm2d(self.expansion * planes)
            )
        else:
            self.final_conv = nn.Sequential(
                nn.ReflectionPad2d(1),
                nn.Conv2d(planes * 2, planes, kernel_size=3, stride=1, padding=0, bias=False),
                nn.InstanceNorm2d(planes)
            )

    def forward(self, x):
        out = F.relu(self.bn1(self.conv1(self.rp1(x))))
        if self.use_dropout:
            out = self.dropout(out)
        out = self.bn2(self.conv2(self.rp2(out)))
        inputt = self.shortcut(x)
        catted = torch.cat((out, inputt), 1)
        out = self.final_conv(catted)
        out = F.relu(out)
        return out


class PyramidFeatures(nn.Module):
    def __init__(self, C2_size, C3_size, C4_size, C5_size, fpn_weights, feature_size=128):
        super(PyramidFeatures, self).__init__()

        self.sum_weights = fpn_weights  # [1.0, 0.5, 0.5, 0.5]

        # upsample C5 to get P5 from the FPN paper
        self.P5_1 = nn.Conv2d(C5_size, feature_size, kernel_size=1, stride=1, padding=0)
        self.P5_upsampled = nn.Upsample(scale_factor=2, mode='nearest')
        # self.rp1 = nn.ReflectionPad2d(1)
        # self.P5_2 = nn.Conv2d(feature_size, feature_size, kernel_size=3, stride=1, padding=0)

        # add P5 elementwise to C4
        self.P4_1 = nn.Conv2d(C4_size, feature_size, kernel_size=1, stride=1, padding=0)
        self.P4_upsampled = nn.Upsample(scale_factor=2, mode='nearest')
        # self.rp2 = nn.ReflectionPad2d(1)
        # self.P4_2 = nn.Conv2d(feature_size, feature_size, kernel_size=3, stride=1, padding=0)

        # add P4 elementwise to C3
        self.P3_1 = nn.Conv2d(C3_size, feature_size, kernel_size=1, stride=1, padding=0)
        self.P3_upsampled = nn.Upsample(scale_factor=2, mode='nearest')
        # self.rp3 = nn.ReflectionPad2d(1)
        # self.P3_2 = nn.Conv2d(feature_size, feature_size, kernel_size=3, stride=1, padding=0)

        self.P2_1 = nn.Conv2d(C2_size, feature_size, kernel_size=1, stride=1, padding=0)
        self.P2_upsampled = nn.Upsample(scale_factor=2, mode='nearest')
        self.rp4 = nn.ReflectionPad2d(1)
        self.P2_2 = nn.Conv2d(int(feature_size), int(feature_size / 2), kernel_size=3, stride=1, padding=0)

        # self.P1_1 = nn.Conv2d(feature_size, feature_size, kernel_size=1, stride=1, padding=0)
        # self.P1_upsampled = nn.Upsample(scale_factor=2, mode='nearest')
        # self.rp5 = nn.ReflectionPad2d(1)
        # self.P1_2 = nn.Conv2d(feature_size, feature_size, kernel_size=3, stride=1, padding=0)

    def forward(self, inputs):
        C2, C3, C4, C5 = inputs

        i = 0
        P5_x = self.P5_1(C5) * self.sum_weights[i]
        P5_upsampled_x = self.P5_upsampled(P5_x)
        # P5_x = self.rp1(P5_x)
        # #P5_x = self.P5_2(P5_x)
        i += 1
        P4_x = self.P4_1(C4) * self.sum_weights[i]
        P4_x = P5_upsampled_x + P4_x
        P4_upsampled_x = self.P4_upsampled(P4_x)
        # P4_x = self.rp2(P4_x)
        # #P4_x = self.P4_2(P4_x)
        i += 1
        P3_x = self.P3_1(C3) * self.sum_weights[i]
        P3_x = P3_x + P4_upsampled_x
        P3_upsampled_x = self.P3_upsampled(P3_x)
        # P3_x = self.rp3(P3_x)
        # P3_x = self.P3_2(P3_x)
        i += 1
        P2_x = self.P2_1(C2) * self.sum_weights[i]
        P2_x = P2_x * self.sum_weights[2] + P3_upsampled_x
        P2_upsampled_x = self.P2_upsampled(P2_x)
        P2_x = self.rp4(P2_upsampled_x)
        P2_x = self.P2_2(P2_x)

        return P2_x


def conv3x3(in_planes, out_planes, stride=1):
    """3x3 convolution with padding"""
    return nn.Conv2d(in_planes, out_planes, kernel_size=3, stride=stride,
                     padding=0, bias=True)
