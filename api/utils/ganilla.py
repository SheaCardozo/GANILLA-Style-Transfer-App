import torch
import numpy as np
from utils.resnet_gen import resnet18
import torchvision.transforms as transforms
from PIL.Image import BICUBIC


def init(model_path):
    net = resnet18(3, 3, 64, [1.0, 1.0, 1.0, 1.0], use_dropout=False)
    net.eval()
    if isinstance(net, torch.nn.DataParallel):
        net = net.module

    state_dict = torch.load(model_path, map_location=torch.device('cpu'))
    if hasattr(state_dict, '_metadata'):
        del state_dict._metadata

    net.load_state_dict(state_dict)

    return net


def forward(real, net):
    data_transforms = transforms.Compose([transforms.Resize(256, BICUBIC),
                                          transforms.RandomCrop(256),
                                          transforms.ToTensor(),
                                          transforms.Normalize((0.5, 0.5, 0.5),
                                                               (0.5, 0.5, 0.5))])

    real = data_transforms(real).to(torch.device('cpu'))[None, :, :, :]

    with torch.no_grad():
        fake = net(real)

    im = tensor2im(fake)

    return im


def tensor2im(input_image, imtype=np.uint8):
    if isinstance(input_image, torch.Tensor):
        image_tensor = input_image.data
    else:
        return input_image
    image_numpy = image_tensor[0].cpu().float().numpy()
    if image_numpy.shape[0] == 1:
        image_numpy = np.tile(image_numpy, (3, 1, 1))
    image_numpy = (np.transpose(image_numpy, (1, 2, 0)) + 1) / 2.0 * 255.0
    return image_numpy.astype(imtype)
