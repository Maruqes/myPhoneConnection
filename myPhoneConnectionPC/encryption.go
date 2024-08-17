package main

import (
	"bytes"
	"compress/gzip"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"io/ioutil"
	"log"
	"math/big"
	"os"
	"path/filepath"
)

func generateRandomKey(length int) ([]byte, error) {
	key := make([]byte, length)
	_, err := rand.Read(key)

	if err != nil {
		return nil, err
	}
	return key, nil
}

func pkcs7Pad(data []byte, blockSize int) []byte {
	padding := blockSize - len(data)%blockSize
	padtext := bytes.Repeat([]byte{byte(padding)}, padding)
	return append(data, padtext...)
}

// pkcs7Unpad removes padding from data.
func pkcs7Unpad(data []byte) ([]byte, error) {
	length := len(data)
	if length == 0 {
		return nil, fmt.Errorf("input data is empty")
	}

	padding := int(data[length-1])
	if padding > length || padding > aes.BlockSize {
		return nil, fmt.Errorf("invalid padding")
	}

	// Check padding bytes
	for _, b := range data[length-padding:] {
		if int(b) != padding {
			return nil, fmt.Errorf("invalid padding byte")
		}
	}

	return data[:length-padding], nil
}

// encryptAES encrypts plain text using AES with the given key.
func encryptAES(key []byte, plainText string) (string, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	plainTextBytes := pkcs7Pad([]byte(plainText), block.BlockSize())
	cipherText := make([]byte, aes.BlockSize+len(plainTextBytes))
	iv := cipherText[:aes.BlockSize] // Using a zero IV for simplicity; use a random IV in production

	mode := cipher.NewCBCEncrypter(block, iv)
	mode.CryptBlocks(cipherText[aes.BlockSize:], plainTextBytes)

	return base64.StdEncoding.EncodeToString(cipherText), nil
}

// decryptAES decrypts cipher text using AES with the given key.
func decryptAES(key []byte, cipherText string) (string, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	cipherTextBytes, err := base64.StdEncoding.DecodeString(cipherText)
	if err != nil {
		return "", err
	}

	if len(cipherTextBytes) < aes.BlockSize {
		return "", fmt.Errorf("cipher text too short")
	}

	iv := cipherTextBytes[:aes.BlockSize]
	cipherTextBytes = cipherTextBytes[aes.BlockSize:]

	if len(cipherTextBytes)%aes.BlockSize != 0 {
		return "", fmt.Errorf("cipher text is not a multiple of the block size")
	}

	mode := cipher.NewCBCDecrypter(block, iv)
	mode.CryptBlocks(cipherTextBytes, cipherTextBytes)

	plainTextBytes, err := pkcs7Unpad(cipherTextBytes)
	if err != nil {
		return "", err
	}

	return string(plainTextBytes), nil
}

func WriteToFile(filename string, data []byte) error {
	err := os.WriteFile(filename, data, 0644)
	if err != nil {
		return err
	}
	return nil
}

func ReadFromFile(filename string) ([]byte, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	return data, nil
}

func decompressData(data []byte) ([]byte, error) {
	buf := bytes.NewBuffer(data)
	gzipReader, err := gzip.NewReader(buf)
	if err != nil {
		return nil, err
	}
	defer gzipReader.Close()
	decompressedData, err := ioutil.ReadAll(gzipReader)
	if err != nil {
		return nil, err
	}
	return decompressedData, nil
}

func compressData(data []byte) ([]byte, error) {
	var buf bytes.Buffer
	gzipWriter := gzip.NewWriter(&buf)
	_, err := gzipWriter.Write(data)
	if err != nil {
		return nil, err
	}
	err = gzipWriter.Close()
	if err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func createRandomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, length)
	for i := range b {
		randIndex, err := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		if err != nil {
			log.Printf("Error generating random index: %v", err)
			return ""
		}
		b[i] = charset[randIndex.Int64()]
	}
	return string(b)
}

func saveImage(imgDecompressed []byte) {
	// Save image to the downloads folder
	downloadsDir, err := os.UserHomeDir()
	if err != nil {
		log.Printf("Error getting user's home directory: %v", err)
		return
	}
	downloadsPath := filepath.Join(downloadsDir, "Downloads")

	fileName := "image" + createRandomString(8) + ".jpeg"
	filePath := filepath.Join(downloadsPath, fileName)

	err = ioutil.WriteFile(filePath, imgDecompressed, 0644)
	if err != nil {
		log.Printf("Error saving image file: %v", err)
		return
	}

	log.Println("Image saved successfully with path:", filePath)
}

func saveTemporaryImage(imgDecompressed []byte) (string, error) {
	// Save image to the temporary folder
	tempDir := os.TempDir()
	fileName := "image" + createRandomString(8) + ".jpeg"
	filePath := filepath.Join(tempDir, fileName)

	err := ioutil.WriteFile(filePath, imgDecompressed, 0644)
	if err != nil {
		log.Printf("Error saving image file: %v", err)
		return "", err
	}

	log.Println("Image saved successfully with path:", filePath)
	return filePath, nil
}

func saveVideo(video []byte) {
	// Save image to the downloads folder
	downloadsDir, err := os.UserHomeDir()
	if err != nil {
		log.Printf("Error getting user's home directory: %v", err)
		return
	}
	downloadsPath := filepath.Join(downloadsDir, "Downloads")

	fileName := "image" + createRandomString(8) + ".mp4"
	filePath := filepath.Join(downloadsPath, fileName)

	err = ioutil.WriteFile(filePath, video, 0644)
	if err != nil {
		log.Printf("Error saving image file: %v", err)
		return
	}

	log.Println("Image saved successfully with path:", filePath)
}
