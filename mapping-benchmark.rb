require 'benchmark'
require 'json'

results = {}
abc = {}

$smallsize = 3
$largesize = 5

def countLUTs(filename)
	lutsizes = File.readlines(filename).filter{ |l| l.start_with?(".names") }.map { |l| (l.split(" ").length - 2) <= $smallsize ? $smallsize : $largesize }
	tally = lutsizes.uniq.map { |s| [s, lutsizes.count(s)] }.to_h
	large = tally[$largesize] ? tally[$largesize] : 0
	small = tally[$smallsize] ? tally[$smallsize] : 0
	large + small / 2
end

def getDepth(filename)
	abcOut = `abc -c "read #{filename}; print_level;"`
	/Level = \s*([0-9]+)\./.match(abcOut.split("\n")[-1]).captures[0].to_i
end

def getBenchmarkFiles
	Dir.each_child("benchmark/mapping/blif/MCNC-big20").filter{ |file| file.split(".")[-1] == 'blif' }.map{ |file|
		title = file.split(".")[0...-1].join('.')
		fullpath = "benchmark/mapping/blif/MCNC-big20/#{file}"
		[title, fullpath]
	}
end

def genABCregular
	results = {}
	outpath = "benchmark/mapping/abc/"
	getBenchmarkFiles.each { |title, path|
		puts "Running abc reference mapping for #{title}..."
		time = Benchmark.measure {
			`abc -c "read_lut benchmark/mapping/library#{$largesize}.lut; read #{path}; if; lutpack; write #{outpath}#{title}.blif"`
		}
		luts = countLUTs("#{outpath}#{title}.blif")
		depth = getDepth("#{outpath}#{title}.blif")

		puts "#{title} completed, #{luts} LUTs, depth #{depth}, #{(time.real * 1000).round}ms end to end"
		results[title] = {:e2e => (time.real * 1000).round, :luts => luts, :depth => depth}
	}
	results
end

def genABCresyn
	results = {}
	outpath = "benchmark/mapping/abc/"
	getBenchmarkFiles.each { |title, path|
		puts "Running abc-resyn reference mapping for #{title}..."
		time = Benchmark.measure {
			`abc -c "read_lut benchmark/mapping/library#{$largesize}.lut; read #{path}; balance; rewrite; rewrite -z; balance; rewrite -z; balance; if; lutpack; write #{outpath}#{title}.blif"`
		}
		luts = countLUTs("#{outpath}#{title}.blif")
		depth = getDepth("#{outpath}#{title}.blif")

		puts "#{title} completed, #{luts} LUTs, depth #{depth}, #{(time.real * 1000).round}ms end to end"
		results[title] = {:e2e => (time.real * 1000).round, :luts => luts, :depth => depth}
	}
	results
end

def genABCresyn3
	results = {}
	outpath = "benchmark/mapping/abc/"
	getBenchmarkFiles.each { |title, path|
		puts "Running abc-resyn3 reference mapping for #{title}..."
		time = Benchmark.measure {
			`abc -c "read_lut benchmark/mapping/library#{$largesize}.lut; read #{path}; balance; resub; resub -K 6; balance; resub -z; resub -z -K 6; balance; resub -z -K 5; balance; if; lutpack; write #{outpath}#{title}.blif"`
		}
		luts = countLUTs("#{outpath}#{title}.blif")
		depth = getDepth("#{outpath}#{title}.blif")

		puts "#{title} completed, #{luts} LUTs, depth #{depth}, #{(time.real * 1000).round}ms end to end"
		results[title] = {:e2e => (time.real * 1000).round, :luts => luts, :depth => depth}
	}
	results
end

def genABCdelay
	results = {}
	outpath = "benchmark/mapping/abc-delay/"
	getBenchmarkFiles.each { |title, path|
		puts "Running abc-delay reference mapping for #{title}..."
		time = Benchmark.measure {
			`abc -c "read_lut benchmark/mapping/library-delay#{$largesize}.lut; read #{path}; if; lutpack; write #{outpath}#{title}.blif"`
		}
		luts = countLUTs("#{outpath}#{title}.blif")
		depthOutput = `abc -c "read #{outpath}#{title}.blif; print_level;"`
		depth = getDepth("#{outpath}#{title}.blif")

		puts "#{title} completed, #{luts} LUTs, depth #{depth}, #{(time.real * 1000).round}ms end to end"
		results[title] = {:e2e => (time.real * 1000).round, :luts => luts, :depth => depth}
	}
	results
end

def genABCfpga
	results = {}
	outpath = "benchmark/mapping/abc-if-repeat/"
	getBenchmarkFiles.each { |title, path|
		puts "Running abc-fpga reference mapping for #{title}..."
		time = Benchmark.measure {
			`abc -c "read_lut benchmark/mapping/library#{$largesize}.lut; read #{path}; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; choice; if; ps; write #{outpath}#{title}.blif"`
		}
		luts = countLUTs("#{outpath}#{title}.blif")
		depthOutput = `abc -c "read #{outpath}#{title}.blif; print_level;"`
		depth = getDepth("#{outpath}#{title}.blif")

		puts "#{title} completed, #{luts} LUTs, depth #{depth}, #{(time.real * 1000).round}ms end to end"
		results[title] = {:e2e => (time.real * 1000).round, :luts => luts, :depth => depth}
	}
	results
end

def genABCisolated
	results = {}
	outpath = "benchmark/mapping/abc-isolated/"
	getBenchmarkFiles.each { |title, path|
		puts "Running abc-isolated reference mapping for #{title}..."
		blif = File.read(path)
		outputLine = /\.outputs(( |\n)(?<wire>[^\s\\\.]+)( \\)?)+/.match(blif)[0]
		outputs = outputLine.gsub("\\", "").gsub("\n", " ").sub(".outputs ", "").split(" ")
		luts = 0

		outputs.each { |out|
		 	isolated = blif.sub(outputLine, ".outputs #{out}")
		 	File.open("/tmp/isolated.blif", "w") { |file| file.puts(isolated) }
		 	`abc -c "read_lut benchmark/mapping/library#{$largesize}.lut; read /tmp/isolated.blif; if; lutpack; write #{outpath}#{title}-#{out}.blif"`
		 	luts += countLUTs("#{outpath}#{title}-#{out}.blif")
		}
		results[title] = {:e2e => 0, :luts => luts, :depth => 0}
	}
	results
end

def genFusemapRegular
	results = {}
	outpath = "benchmark/mapping/fusemap/"
	`rm #{outpath}*.blif`

	getBenchmarkFiles.each { |title, path|
		puts "Running fusemap mapping for #{title}..."
		output = ""
		time = Benchmark.measure {
			output = `java -jar build/libs/obdd-gen-2.0-all.jar --blif-map --lutcap=#{$largesize} --loglevel=5 --out=#{outpath}#{title}.blif #{path}`
		}
		luts = countLUTs("#{outpath}#{title}.blif")
		depth = getDepth("#{outpath}#{title}.blif")
		mapTime = output.chomp.split("|")[0].to_i

		verification = `abc -c "cec #{outpath}#{title}.blif #{path}"`
		puts verification =~ /Networks are equivalent/ ? "VERIFICATION OK" : "VERIFICATION FAILURE"

		puts "#{title} completed, #{luts} LUTs, depth #{depth}, #{(time.real * 1000).round}ms end to end"
		results[title] = {:e2e => (time.real * 1000).round, :luts => luts, :depth => depth, :map => mapTime}
	}
	results
end


def genFusemapLutpack
	results = {}
	outpath = "benchmark/mapping/fusemap-pack/"
	`rm #{outpath}*.blif`

	getBenchmarkFiles.each { |title, path|
		puts "Running fusemap mapping for #{title}..."
		output = ""
		time = Benchmark.measure {
			output = `java -jar build/libs/obdd-gen-2.0-all.jar --blif-map --lutcap=#{$largesize} --loglevel=5 --out=#{outpath}#{title}.blif #{path}`
			`abc -c "read_lut benchmark/mapping/library#{$largesize}.lut; read #{outpath}#{title}.blif; lutpack; write #{outpath}#{title}.blif"`
		}
		luts = countLUTs("#{outpath}#{title}.blif")
		depth = getDepth("#{outpath}#{title}.blif")
		mapTime = output.chomp.split("|")[0].to_i

		verification = `abc -c "cec #{outpath}#{title}.blif #{path}"`
		puts verification =~ /Networks are equivalent/ ? "VERIFICATION OK" : "VERIFICATION FAILURE"

		puts "#{title} completed, #{luts} LUTs, depth #{depth}, #{(time.real * 1000).round}ms end to end"
		results[title] = {:e2e => (time.real * 1000).round, :luts => luts, :depth => depth, :map => mapTime}
	}
	results
end

abc = genABCregular()
#abcDelay = genABCdelay()
#abcIsolated = genABCisolated()
#abcResyn = genABCresyn()
#abcResyn3 = genABCresyn3()
#abcFpga = genABCfpga()
#fusemap = genFusemapRegular()
fusemapPack = genFusemapLutpack()

puts JSON.dump(abc)
#puts JSON.dump(abcDelay)
#puts JSON.dump(abcIsolated)
#puts JSON.dump(abcResyn)
#puts JSON.dump(abcResyn3)
#puts JSON.dump(abcFpga)
#puts JSON.dump(fusemap)
puts JSON.dump(fusemapPack)