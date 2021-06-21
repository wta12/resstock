# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

resources_path = File.absolute_path(File.join(File.dirname(__FILE__), '../HPXMLtoOpenStudio/resources'))
unless File.exist? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, 'HPXMLtoOpenStudio/resources') # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, 'geometry')
require File.join(resources_path, 'weather')
require File.join(resources_path, 'lighting')

# start the measure
class ResidentialLightingOther < OpenStudio::Measure::ModelMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Set Residential Other Lighting'
  end

  def description
    return "Sets (or replaces) the lighting energy use, based on fractions of CFLs, LFLs, and LEDs, for the garage and outside. For multifamily buildings, the lighting can be set for all units of the building.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return 'Assigns a lighting energy use and schedule to the garage and outside. The lighting schedule, by default, is calculated for the latitude/longitude of the weather location specified in the model.'
  end

  # define the arguments that the user will input
  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a choice argument for option type
    choices = []
    choices << Constants.OptionTypeLightingFractions
    choices << Constants.OptionTypeLightingEnergyUses
    option_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('option_type', choices, true)
    option_type.setDisplayName('Option Type')
    option_type.setDescription('Inputs are used/ignored below based on the option type specified.')
    option_type.setDefaultValue(Constants.OptionTypeLightingFractions)
    args << option_type

    # make a double argument for hardwired CFL fraction
    hw_cfl = OpenStudio::Measure::OSArgument::makeDoubleArgument('hw_cfl', true)
    hw_cfl.setDisplayName("#{Constants.OptionTypeLightingFractions}: Hardwired Fraction CFL")
    hw_cfl.setDescription('Fraction of all hardwired lamps (garage and exterior) that are compact fluorescent. Hardwired lighting not specified as CFL, LED, or LFL is assumed to be incandescent.')
    hw_cfl.setDefaultValue(0.34)
    args << hw_cfl

    # make a double argument for hardwired LED fraction
    hw_led = OpenStudio::Measure::OSArgument::makeDoubleArgument('hw_led', true)
    hw_led.setDisplayName("#{Constants.OptionTypeLightingFractions}: Hardwired Fraction LED")
    hw_led.setDescription('Fraction of all hardwired lamps (garage and exterior) that are LED. Hardwired lighting not specified as CFL, LED, or LFL is assumed to be incandescent.')
    hw_led.setDefaultValue(0)
    args << hw_led

    # make a double argument for hardwired LFL fraction
    hw_lfl = OpenStudio::Measure::OSArgument::makeDoubleArgument('hw_lfl', true)
    hw_lfl.setDisplayName("#{Constants.OptionTypeLightingFractions}: Hardwired Fraction LFL")
    hw_lfl.setDescription('Fraction of all hardwired lamps (garage and exterior) that are linear fluorescent. Hardwired lighting not specified as CFL, LED, or LFL is assumed to be incandescent.')
    hw_lfl.setDefaultValue(0)
    args << hw_lfl

    # make a double argument for Plugin CFL fraction
    pg_cfl = OpenStudio::Measure::OSArgument::makeDoubleArgument('pg_cfl', true)
    pg_cfl.setDisplayName("#{Constants.OptionTypeLightingFractions}: Plugin Fraction CFL")
    pg_cfl.setDescription('Fraction of all plugin lamps that are compact fluorescent. Plugin lighting not specified as CFL, LED, or LFL is assumed to be incandescent.')
    pg_cfl.setDefaultValue(0.34)
    args << pg_cfl

    # make a double argument for Plugin LED fraction
    pg_led = OpenStudio::Measure::OSArgument::makeDoubleArgument('pg_led', true)
    pg_led.setDisplayName("#{Constants.OptionTypeLightingFractions}: Plugin Fraction LED")
    pg_led.setDescription('Fraction of all plugin lamps that are LED. Plugin lighting not specified as CFL, LED, or LFL is assumed to be incandescent.')
    pg_led.setDefaultValue(0)
    args << pg_led

    # make a double argument for Plugin LFL fraction
    pg_lfl = OpenStudio::Measure::OSArgument::makeDoubleArgument('pg_lfl', true)
    pg_lfl.setDisplayName("#{Constants.OptionTypeLightingFractions}: Plugin Fraction LFL")
    pg_lfl.setDescription('Fraction of all plugin lamps that are linear fluorescent. Plugin lighting not specified as CFL, LED, or LFL is assumed to be incandescent.')
    pg_lfl.setDefaultValue(0)
    args << pg_lfl

    # make a double argument for BA Benchmark multiplier
    mult = OpenStudio::Measure::OSArgument::makeDoubleArgument('mult', true)
    mult.setDisplayName("#{Constants.OptionTypeLightingFractions}: Multiplier")
    mult.setDescription('A multiplier on the national average lighting energy. 0.75 indicates a 25% reduction in the lighting energy, 1.0 indicates the same lighting energy as the national average, 1.25 indicates a 25% increase in the lighting energy, etc.')
    mult.setDefaultValue(1)
    args << mult

    # make a double argument for Incandescent Efficacy
    in_eff = OpenStudio::Measure::OSArgument::makeDoubleArgument('in_eff', true)
    in_eff.setDisplayName("#{Constants.OptionTypeLightingFractions}: Incandescent Efficacy")
    in_eff.setUnits('lm/W')
    in_eff.setDescription('The ratio of light output from an incandescent lamp to the electric power it consumes.')
    in_eff.setDefaultValue(15)
    args << in_eff

    # make a double argument for CFL Efficacy
    cfl_eff = OpenStudio::Measure::OSArgument::makeDoubleArgument('cfl_eff', true)
    cfl_eff.setDisplayName("#{Constants.OptionTypeLightingFractions}: CFL Efficacy")
    cfl_eff.setUnits('lm/W')
    cfl_eff.setDescription('The ratio of light output from a CFL lamp to the electric power it consumes.')
    cfl_eff.setDefaultValue(55)
    args << cfl_eff

    # make a double argument for LED Efficacy
    led_eff = OpenStudio::Measure::OSArgument::makeDoubleArgument('led_eff', true)
    led_eff.setDisplayName("#{Constants.OptionTypeLightingFractions}: LED Efficacy")
    led_eff.setUnits('lm/W')
    led_eff.setDescription('The ratio of light output from a LED lamp to the electric power it consumes.')
    led_eff.setDefaultValue(80)
    args << led_eff

    # make a double argument for LFL Efficacy
    lfl_eff = OpenStudio::Measure::OSArgument::makeDoubleArgument('lfl_eff', true)
    lfl_eff.setDisplayName("#{Constants.OptionTypeLightingFractions}: LFL Efficacy")
    lfl_eff.setUnits('lm/W')
    lfl_eff.setDescription('The ratio of light output from a LFL lamp to the electric power it consumes.')
    lfl_eff.setDefaultValue(88)
    args << lfl_eff

    # make a double argument for garage energy use
    energy_use_garage = OpenStudio::Measure::OSArgument::makeDoubleArgument('energy_use_garage', true)
    energy_use_garage.setDisplayName("#{Constants.OptionTypeLightingEnergyUses}: Garage")
    energy_use_garage.setUnits('kWh/year')
    energy_use_garage.setDescription('Total garage annual lighting energy use. Only applied if there is a garage space.')
    energy_use_garage.setDefaultValue(100)
    args << energy_use_garage

    # make a double argument for exterior energy use
    energy_use_exterior = OpenStudio::Measure::OSArgument::makeDoubleArgument('energy_use_exterior', true)
    energy_use_exterior.setDisplayName("#{Constants.OptionTypeLightingEnergyUses}: Exterior")
    energy_use_exterior.setUnits('kWh/year')
    energy_use_exterior.setDescription('Total exterior annual lighting energy use.')
    energy_use_exterior.setDefaultValue(300)
    args << energy_use_exterior

    # make a double argument for exterior energy use during holiday period
    holiday_daily_energy_use_exterior = OpenStudio::Measure::OSArgument::makeDoubleArgument('holiday_daily_energy_use_exterior', true)
    holiday_daily_energy_use_exterior.setDisplayName("#{Constants.OptionTypeLightingEnergyUses}: Holiday Exterior")
    holiday_daily_energy_use_exterior.setUnits('kWh/day')
    holiday_daily_energy_use_exterior.setDescription('Daily exterior lighting energy use during holiday period.')
    holiday_daily_energy_use_exterior.setDefaultValue(0)
    args << holiday_daily_energy_use_exterior

    # make a string argument for start date of the holiday period
    holiday_start_date = OpenStudio::Measure::OSArgument.makeStringArgument('holiday_start_date', true)
    holiday_start_date.setDisplayName('Holiday Period Start Date')
    holiday_start_date.setDescription('Date of the start of the holiday period.')
    holiday_start_date.setDefaultValue('November 27')
    args << holiday_start_date

    # make a string argument for end date of the holiday period
    holiday_end_date = OpenStudio::Measure::OSArgument.makeStringArgument('holiday_end_date', true)
    holiday_end_date.setDisplayName('Holiday Period End Date')
    holiday_end_date.setDescription('Date of the end of the holiday period.')
    holiday_end_date.setDefaultValue('January 6')
    args << holiday_end_date

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    option_type = runner.getStringArgumentValue('option_type', user_arguments)
    hw_cfl = runner.getDoubleArgumentValue('hw_cfl', user_arguments)
    hw_led = runner.getDoubleArgumentValue('hw_led', user_arguments)
    hw_lfl = runner.getDoubleArgumentValue('hw_lfl', user_arguments)
    pg_cfl = runner.getDoubleArgumentValue('pg_cfl', user_arguments)
    pg_led = runner.getDoubleArgumentValue('pg_led', user_arguments)
    pg_lfl = runner.getDoubleArgumentValue('pg_lfl', user_arguments)
    mult = runner.getDoubleArgumentValue('mult', user_arguments)
    in_eff = runner.getDoubleArgumentValue('in_eff', user_arguments)
    cfl_eff = runner.getDoubleArgumentValue('cfl_eff', user_arguments)
    led_eff = runner.getDoubleArgumentValue('led_eff', user_arguments)
    lfl_eff = runner.getDoubleArgumentValue('lfl_eff', user_arguments)
    energy_use_garage = runner.getDoubleArgumentValue('energy_use_garage', user_arguments)
    energy_use_exterior = runner.getDoubleArgumentValue('energy_use_exterior', user_arguments)
    holiday_daily_energy_use_exterior = runner.getDoubleArgumentValue('holiday_daily_energy_use_exterior', user_arguments)
    holiday_start_date = runner.getStringArgumentValue('holiday_start_date', user_arguments)
    holiday_end_date = runner.getStringArgumentValue('holiday_end_date', user_arguments)

    # Check for valid inputs
    if option_type == Constants.OptionTypeLightingFractions
      if (hw_cfl < 0) || (hw_cfl > 1)
        runner.registerError('Hardwired Fraction CFL must be greater than or equal to 0 and less than or equal to 1.')
        return false
      end
      if (hw_led < 0) || (hw_led > 1)
        runner.registerError('Hardwired Fraction LED must be greater than or equal to 0 and less than or equal to 1.')
        return false
      end
      if (hw_lfl < 0) || (hw_lfl > 1)
        runner.registerError('Hardwired Fraction LFL must be greater than or equal to 0 and less than or equal to 1.')
        return false
      end
      if hw_cfl + hw_led + hw_lfl > 1
        runner.registerError('Sum of CFL, LED, and LFL Hardwired Fractions must be less than or equal to 1.')
        return false
      end
      if (pg_cfl < 0) || (pg_cfl > 1)
        runner.registerError('Plugin Fraction CFL must be greater than or equal to 0 and less than or equal to 1.')
        return false
      end
      if (pg_led < 0) || (pg_led > 1)
        runner.registerError('Plugin Fraction LED must be greater than or equal to 0 and less than or equal to 1.')
        return false
      end
      if (pg_lfl < 0) || (pg_lfl > 1)
        runner.registerError('Plugin Fraction LFL must be greater than or equal to 0 and less than or equal to 1.')
        return false
      end
      if pg_cfl + pg_led + pg_lfl > 1
        runner.registerError('Sum of CFL, LED, and LFL Plugin Fractions must be less than or equal to 1.')
        return false
      end
      if mult < 0
        runner.registerError('Lamps used multiplier must be greater than or equal to 0.')
        return false
      end
      if in_eff <= 0
        runner.registerError('Incandescent Efficacy must be greater than 0.')
        return false
      end
      if cfl_eff <= 0
        runner.registerError('CFL Efficacy must be greater than 0.')
        return false
      end
      if led_eff <= 0
        runner.registerError('LED Efficacy must be greater than 0.')
        return false
      end
      if lfl_eff <= 0
        runner.registerError('LFL Efficacy must be greater than 0.')
        return false
      end
    elsif option_type == Constants.OptionTypeLightingEnergyUses
      if energy_use_garage < 0
        runner.registerError("#{Constants.OptionTypeLightingEnergyUses}: Garage must be greater than or equal to 0.")
        return false
      end
      if energy_use_exterior < 0
        runner.registerError("#{Constants.OptionTypeLightingEnergyUses}: Exterior must be greater than or equal to 0.")
        return false
      end
      if holiday_daily_energy_use_exterior < 0
        runner.registerError("#{Constants.OptionTypeLightingEnergyUses}: Holiday Exterior must be greater than or equal to 0.")
        return false
      end
    end

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
      return false
    end

    # Calculate the lighting schedule
    weather = WeatherProcess.new(model, runner)
    if weather.error?
      return false
    end

    # Incandescent fractions
    hw_inc = 1 - hw_cfl - hw_led - hw_lfl
    pg_inc = 1 - pg_cfl - pg_led - pg_lfl

    Lighting.remove_other(model, runner)

    schedules_file = SchedulesFile.new(runner: runner, model: model)
    if not schedules_file.validated?
      return false
    end

    tot_ltg_e = 0
    msgs = []

    # Garage lighting (garages not associated with a unit)
    garage_spaces = Geometry.get_garage_spaces(model.getSpaces)
    gfa = Geometry.get_floor_area_from_spaces(garage_spaces)
    if option_type == Constants.OptionTypeLightingEnergyUses
      garage_ann = energy_use_garage
    elsif option_type == Constants.OptionTypeLightingFractions  
      hw_fl = hw_cfl + hw_lfl
      fl_eff = cfl_eff
  
      # Efficacy ratios
      eff_ratio_inc = in_eff / in_eff
      eff_ratio_fl = in_eff / fl_eff
      eff_ratio_led = in_eff / led_eff
      
      # Efficiency lighting adjustments
      grg_adj  = (hw_inc * eff_ratio_inc) + (hw_fl * eff_ratio_fl) + (hw_led * eff_ratio_led)
      # Calculate energy use
      garage_ann = mult * 100.0 * grg_adj  
    end

    success = Lighting.apply_garage(model, runner, weather, garage_ann, schedules_file)
    return false if not success

    schedules_file.set_vacancy(col_name: 'lighting_garage')

    if garage_spaces.length > 0
      msgs << "Lighting with #{garage_ann.round} kWhs annual energy consumption has been assigned to the garage(s)."
      tot_ltg_e += garage_ann
    end

    # Exterior Lighting
    exterior_ann = 0
    if option_type == Constants.OptionTypeLightingEnergyUses
      exterior_ann = energy_use_exterior
    elsif option_type == Constants.OptionTypeLightingFractions
      total_ffa = Geometry.get_finished_floor_area_from_spaces(model.getSpaces, runner)
      hw_fl = hw_cfl + hw_lfl
      fl_eff = cfl_eff
  
      # Efficacy ratios
      eff_ratio_inc = in_eff / in_eff
      eff_ratio_fl = in_eff / fl_eff
      eff_ratio_led = in_eff / led_eff
      
      # Efficiency lighting adjustments
      ext_adj = (hw_inc * eff_ratio_inc) + (hw_fl * eff_ratio_fl) + (hw_led * eff_ratio_led)
      # Calculate energy use
      exterior_ann = mult * (100.0 + 0.05 * total_ffa) * ext_adj
    end

    if exterior_ann > 0
      success = Lighting.apply_exterior(model, runner, weather, exterior_ann, schedules_file)
      return false if not success

      schedules_file.set_vacancy(col_name: 'lighting_exterior')
    end

    msgs << "Lighting with #{exterior_ann.round} kWhs annual energy consumption has been assigned to the exterior."
    tot_ltg_e += exterior_ann

    # Exterior Holiday Lighting
    if holiday_daily_energy_use_exterior > 0
      year_description = model.getYearDescription
      assumed_year = year_description.assumedYear

      months = { 'January' => 1, 'February' => 2, 'March' => 3, 'April' => 4, 'May' => 5, 'June' => 6, 'July' => 7, 'August' => 8, 'September' => 9, 'October' => 10, 'November' => 11, 'December' => 12 }
      holiday_start_month = months[holiday_start_date.split[0]]
      holiday_end_month = months[holiday_end_date.split[0]]

      if holiday_start_month.nil? || holiday_end_month.nil?
        runner.registerError('Invalid holiday period month(s) entered.')
        return false
      end

      holiday_start_day = holiday_start_date.split[1].to_i
      holiday_end_day = holiday_end_date.split[1].to_i

      begin
        holiday_start = Time.new(assumed_year, holiday_start_month, holiday_start_day)
        holiday_end = Time.new(assumed_year, holiday_end_month, holiday_end_day)
      rescue
        runner.registerError('Invalid holiday period date(s) entered.')
        return false
      end

      if holiday_start < holiday_end # contiguous holiday
        num_holiday_seconds = (holiday_end - holiday_start)
      else # non contiguous holiday
        num_holiday_seconds = (holiday_end - Time.new(assumed_year)) + (Time.new(assumed_year + 1) - holiday_start)
      end
      num_holiday_days = (num_holiday_seconds / 3600 / 24).to_i + 1
      holiday_exterior_ann = num_holiday_days * holiday_daily_energy_use_exterior

      success = Lighting.apply_exterior_holiday(model, runner, holiday_exterior_ann, schedules_file)
      return false if not success

      msgs << "Holiday lighting with #{holiday_exterior_ann.round} kWhs annual energy consumption has been assigned to the exterior from #{holiday_start_date} until #{holiday_end_date}."
      tot_ltg_e += holiday_exterior_ann

      schedules_file.set_vacancy(col_name: 'lighting_exterior_holiday')
    end

    # reporting final condition of model
    if msgs.size > 1
      msgs.each do |msg|
        runner.registerInfo(msg)
      end
      runner.registerFinalCondition("The building has been assigned garage and exterior lighting totaling #{tot_ltg_e.round} kWhs annual energy consumption across #{units.size} units.")
    elsif msgs.size == 1
      runner.registerFinalCondition(msgs[0])
    else
      runner.registerFinalCondition('No garage or exterior lighting has been assigned.')
    end

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ResidentialLightingOther.new.registerWithApplication
