package gomod

import (
	"context"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
)

// DirCacher implements the `Cacher` using a directory on the local filesystem.
// If the directory does not exist, it will be created with 0750 permissions.
type DirCacher string

// Get implements the `Cacher`.
func (dc DirCacher) Get(
	ctx context.Context,
	name string,
) (io.ReadCloser, error) {
	fileName := filepath.Join(string(dc), filepath.FromSlash(name))

	fileInfo, err := os.Stat(fileName)
	if err != nil {
		return nil, err
	}

	file, err := os.Open(fileName)
	if err != nil {
		return nil, err
	}

	return &struct {
		*os.File
		os.FileInfo
	}{
		File:     file,
		FileInfo: fileInfo,
	}, nil
}

// Set implements the `Cacher`.
func (dc DirCacher) Set(
	ctx context.Context,
	name string,
	content io.ReadSeeker,
) error {
	fileName := filepath.Join(string(dc), filepath.FromSlash(name))

	dir := filepath.Dir(fileName)
	if err := os.MkdirAll(dir, 0750); err != nil {
		return err
	}

	file, err := ioutil.TempFile(dir, "")
	if err != nil {
		return err
	}
	defer os.Remove(file.Name())

	if _, err := io.Copy(file, content); err != nil {
		return err
	}

	if err := file.Close(); err != nil {
		return err
	}

	return os.Rename(file.Name(), fileName)
}
