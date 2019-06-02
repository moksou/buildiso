# buildiso
Простенький bash-скрипт для сборки кастомных образов CentOS 7 Minimal/DVD.
# Зависимости
- CentOS 7
- genisoimage
- syslinux
- createrepo
- isomd5sum

Крайне рекомендуется установить все зависимости прежде, чем запускать скрипт.

# Usage
Запускается от рута
```sh
# ./buildiso -i [source ISO] -o [destination ISO] -k [path to kickstart] -h [hostname]
```

# Параметры
- `-i` - оригинальный образ CentOS 7 (Minimal или DVD, Live-сборки не работают) (обязательный аргумент)
- `-o` - путь до сгенерированного образа (необязательный аргумент, по умолчанию `/var/lib/libvirt/images/CentOS-7-x86_64-Minimal-1804-Kickstart.iso`)
- `-k` - путь до Kickstart-файла (необязательный аргумент, по умолчанию kickstart берется из папки `cfg`
- `-h` - хостнейм (необязательный аргумент, по умолчанию `hostname`)
- `-p` - директория с пакетами (необязательный аргумент, по умолчанию `packages`)

# Принцип работы
Скрипт монтирует оригинальный образ центоси в `src` (создает директорию, если ее нету) и копирует все файлы в директорию `data` (создает, если ее нету), которая будет рабочей и из которой будем собирать образ. После копирования образ размонтируется.
Копируются все пакеты из директории `packages` в соответствующую `data/Packages` и лезет в папку `data/repodata`, где лежат базы данных пакетов. Берет оттуда файл, похожий на `data/repodata/*-c7-x86_64-comps.xml`, переименовывает его в `data/repodata/comps.xml` и передает его в качестве аргумента утилите createrepo, которая генерирует базу данных с новыми пакетами и учитывает их группы.
Затем идет перезапись конфигурационных файлов:
- `data/ks.cfg` - kickstart-файл по умолчанию, можно поменять на другой при указании параметра `-k`
- `data/isolinux/isolinux.cfg` - загрузочный конфиг isolinux
- `data/EFI/BOOT/grub.cfg` - конфиг grub'а для загрузки с UEFI.

В этот момент в kickstart-файле происходит правка хостнейма на указанный.

Последний штрих - идет конфигурация образа `data/images/efiboot.img` для загрузки с EFI. Файл монтируется в папку `efi` и внутри него переписывается файл `efi/EFI/BOOT/grub.cfg` на указанный выше. Образ размонтируется.

После этого идет уже непосредственно сборка утилитой genisoimage, вставка в него md5-хэша для проверки записанного образа и его модификация для загрузки с UEFI.

После сборки все содержимое в папке `data` удаляется.