function(ice40_synth)

	set(options)

	set(oneValueArgs 
		TARGET
		TOP_LEVEL_VERILOG
		PCF_FILE
		YOSYS_PATH
		NEXTPNR_PATH
		ICEPACK_PATH
		FPGA_TYPE
		FPGA_PKG
	)
	set(multiValueArgs VERILOG_DEPENDS)
	cmake_parse_arguments(SYNTH "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	find_program(YOSYS_COMMAND yosys
		HINT ${SYNTH_YOSYS_PATH} ENV YOSYS_PATH
	)
	find_program(NEXTPNR_COMMAND nextpnr-ice40
		HINT ${SYNTH_NEXTPNR_PATH} ENV NEXTPNR_PATH
	)
	find_program(ICEPACK_COMMAND icepack
		HINT ${SYNTH_ICEPACK_PATH} ENV ICEPACK_PATH
	)
	find_program(ICETIME_COMMAND icetime
		HINT ${SYNTH_ICEPACK_PATH} ENV ICEPACK_PATH
	)

	get_filename_component(TOP_LEVEL_NAME ${SYNTH_TOP_LEVEL_VERILOG} NAME_WE)

	add_custom_target(${SYNTH_TARGET}.bin ALL
		COMMAND
			${ICEPACK_COMMAND} ${SYNTH_TARGET}.asc ${SYNTH_TARGET}.bin
		DEPENDS
			${SYNTH_TARGET}.asc
		)

	add_custom_target(${SYNTH_TARGET}.rpt ALL
		COMMAND
			${ICETIME_COMMAND} -d ${SYNTH_FPGA_TYPE} -P ${SYNTH_FPGA_PKG}
				-p ${CMAKE_CURRENT_SOURCE_DIR}/${SYNTH_PCF_FILE} -mtr ${SYNTH_TARGET}.rpt ${SYNTH_TARGET}.asc
		DEPENDS
			${SYNTH_TARGET}.asc
			${SYNTH_PCF_FILE}
		)

	add_custom_target(${SYNTH_TARGET}.asc
		COMMAND
			${NEXTPNR_COMMAND} --${SYNTH_FPGA_TYPE} --package ${SYNTH_FPGA_PKG} --json ${SYNTH_TARGET}.json
				--pcf ${CMAKE_CURRENT_SOURCE_DIR}/${SYNTH_PCF_FILE} --asc ${SYNTH_TARGET}.asc
		DEPENDS
			${SYNTH_TARGET}.json
			${SYNTH_PCF_FILE}
		)

	add_custom_target(${SYNTH_TARGET}.json
		COMMAND
		${YOSYS_COMMAND} -ql ${CMAKE_CURRENT_BINARY_DIR}/${SYNTH_TARGET}-yosys.log -p 
				'synth_ice40 -top ${TOP_LEVEL_NAME} -json ${CMAKE_CURRENT_BINARY_DIR}/${SYNTH_TARGET}.json'
				${SYNTH_TOP_LEVEL_VERILOG}
		WORKING_DIRECTORY
			${CMAKE_CURRENT_SOURCE_DIR}
		BYPRODUCTS
			${SYNTH_TARGET}-yosys.log
		DEPENDS
			${SYNTH_TOP_LEVEL_VERILOG}
			${SYNTH_VERILOG_DEPENDS}
		)

endfunction()

function(ice40_sim)

	set(options)

	set(oneValueArgs
		TARGET
		TOP_LEVEL_VERILOG
		YOSYS_PATH
		NEXTPNR_PATH
		ICEPACK_PATH
	)
	set(multiValueArgs VERILOG_DEPENDS)
	cmake_parse_arguments(SYNTH "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	find_program(YOSYS_COMMAND yosys
		HINT ${SYNTH_YOSYS_PATH} ENV YOSYS_PATH
	)

	find_program(YOSYS_CONFIG_COMMAND yosys-config
		HINT ${SYNTH_YOSYS_PATH} ENV YOSYS_PATH
	)

	get_filename_component(TOP_LEVEL_NAME ${SYNTH_TOP_LEVEL_VERILOG} NAME_WE)

	add_custom_target(${SYNTH_TARGET}.hpp
		COMMAND
		${YOSYS_COMMAND} -ql ${CMAKE_CURRENT_BINARY_DIR}/${SYNTH_TARGET}-yosys.log -p
				'read_verilog ${SYNTH_TOP_LEVEL_VERILOG}\; write_cxxrtl ${CMAKE_CURRENT_BINARY_DIR}/${SYNTH_TARGET}.hpp'
		WORKING_DIRECTORY
			${CMAKE_CURRENT_SOURCE_DIR}
		BYPRODUCTS
			${SYNTH_TARGET}-yosys.log
		DEPENDS
			${SYNTH_TOP_LEVEL_VERILOG}
			${SYNTH_VERILOG_DEPENDS}
		)

	add_library(${SYNTH_TARGET} INTERFACE)
	add_dependencies(${SYNTH_TARGET} ${SYNTH_TARGET}.hpp)
	target_include_directories(${SYNTH_TARGET} INTERFACE ${CMAKE_CURRENT_BINARY_DIR})
	execute_process(COMMAND ${YOSYS_CONFIG_COMMAND} --datdir OUTPUT_VARIABLE YOSYS_DATADIR OUTPUT_STRIP_TRAILING_WHITESPACE)
	target_include_directories(${SYNTH_TARGET} INTERFACE ${YOSYS_DATADIR}/include)

endfunction()
